use std::collections::HashMap;

#[derive(Clone, Copy)]
pub enum Protocol {
    Aave,
    Compound,
    Morpho,
}

pub struct Constituent {
    pub name: String,
    pub protocol: Protocol,
    pub target_weight_bps: u16,
    pub phase_in: f64,
}

pub trait RateSource {
    fn borrow_rate(&self, c: &Constituent) -> Result<f64, String>;
}

#[derive(Default)]
pub struct MockSource {
    rates: HashMap<String, f64>,
}

impl MockSource {
    pub fn set(&mut self, name: &str, rate: f64) {
        self.rates.insert(name.to_string(), rate);
    }
}

impl RateSource for MockSource {
    fn borrow_rate(&self, c: &Constituent) -> Result<f64, String> {
        self.rates
            .get(&c.name)
            .copied()
            .ok_or_else(|| format!("no rate for {}", c.name))
    }
}

pub const SECONDS_PER_YEAR: f64 = 365.0 * 24.0 * 3600.0;
pub const SELECTOR_GET_RESERVE_DATA: [u8; 4] = [0x35, 0xea, 0x6a, 0x75];

pub fn word_at(ret: &[u8], idx: usize) -> Option<[u8; 32]> {
    let start = idx * 32;
    let end = start + 32;
    if ret.len() < end {
        return None;
    }
    let mut w = [0u8; 32];
    w.copy_from_slice(&ret[start..end]);
    Some(w)
}

pub fn u128_be(w: &[u8; 32]) -> u128 {
    let mut b = [0u8; 16];
    b.copy_from_slice(&w[16..32]);
    u128::from_be_bytes(b)
}

pub fn ray_to_f64(w: &[u8; 32]) -> f64 {
    u128_be(w) as f64 / 1e27
}

pub fn wad_to_f64(w: &[u8; 32]) -> f64 {
    u128_be(w) as f64 / 1e18
}

pub fn per_second_to_apr(rate_per_sec: f64) -> f64 {
    rate_per_sec * SECONDS_PER_YEAR
}

#[cfg(feature = "live")]
pub mod live {
    use super::*;

    pub struct RpcClient {
        pub url: String,
    }

    impl RpcClient {
        pub fn eth_call(&self, to: &str, data: &str) -> Result<Vec<u8>, String> {
            let body = serde_json::json!({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_call",
                "params": [{ "to": to, "data": data }, "latest"]
            });
            let resp: serde_json::Value = ureq::post(&self.url)
                .send_json(body)
                .map_err(|e| e.to_string())?
                .into_json()
                .map_err(|e| e.to_string())?;
            let hex = resp["result"].as_str().ok_or("no result")?;
            decode_hex(hex)
        }
    }

    pub struct EthCallSource {
        pub rpc: RpcClient,
        pub to: String,
        pub calldata: String,
        pub word_index: usize,
        pub ray: bool,
    }

    impl EthCallSource {
        pub fn aave(rpc_url: &str, pool: &str, asset: &str) -> Self {
            let mut data = Vec::new();
            data.extend_from_slice(&SELECTOR_GET_RESERVE_DATA);
            data.extend_from_slice(&address_word(asset));
            Self {
                rpc: RpcClient { url: rpc_url.to_string() },
                to: pool.to_string(),
                calldata: encode_hex(&data),
                word_index: 4,
                ray: true,
            }
        }
    }

    impl RateSource for EthCallSource {
        fn borrow_rate(&self, _c: &Constituent) -> Result<f64, String> {
            let ret = self.rpc.eth_call(&self.to, &self.calldata)?;
            let w = word_at(&ret, self.word_index).ok_or("short return")?;
            Ok(if self.ray { ray_to_f64(&w) } else { wad_to_f64(&w) })
        }
    }

    fn address_word(addr: &str) -> [u8; 32] {
        let bytes = decode_hex(addr).unwrap_or_default();
        let mut w = [0u8; 32];
        if bytes.len() == 20 {
            w[12..32].copy_from_slice(&bytes);
        }
        w
    }

    pub fn encode_hex(bytes: &[u8]) -> String {
        let mut s = String::from("0x");
        for b in bytes {
            s.push_str(&format!("{:02x}", b));
        }
        s
    }

    pub fn decode_hex(s: &str) -> Result<Vec<u8>, String> {
        let s = s.strip_prefix("0x").unwrap_or(s);
        if s.len() % 2 != 0 {
            return Err("odd hex length".to_string());
        }
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).map_err(|e| e.to_string()))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn word_from_u128(v: u128) -> [u8; 32] {
        let mut w = [0u8; 32];
        w[16..32].copy_from_slice(&v.to_be_bytes());
        w
    }

    #[test]
    fn ray_decode() {
        let w = word_from_u128(70_000_000_000_000_000_000_000_000u128);
        assert!((ray_to_f64(&w) - 0.07).abs() < 1e-9);
    }

    #[test]
    fn wad_decode() {
        let w = word_from_u128(65_000_000_000_000_000u128);
        assert!((wad_to_f64(&w) - 0.065).abs() < 1e-12);
    }

    #[test]
    fn word_offset() {
        let mut ret = vec![0u8; 32 * 5];
        ret[32 * 4 + 31] = 1;
        let w = word_at(&ret, 4).unwrap();
        assert_eq!(u128_be(&w), 1);
        assert!(word_at(&ret, 5).is_none());
    }

    #[test]
    fn apr_from_per_second() {
        let r = per_second_to_apr(0.07 / SECONDS_PER_YEAR);
        assert!((r - 0.07).abs() < 1e-12);
    }
}
