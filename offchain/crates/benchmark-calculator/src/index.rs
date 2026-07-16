use crate::sources::{Constituent, RateSource};

pub struct BenchmarkIndex {
    pub constituents: Vec<Constituent>,
}

impl BenchmarkIndex {
    pub fn new(constituents: Vec<Constituent>) -> Self {
        Self { constituents }
    }

    pub fn compute<S: RateSource>(&self, src: &S) -> Result<f64, String> {
        let mut weighted_sum = 0.0f64;
        let mut total_weight = 0.0f64;

        for c in &self.constituents {
            let rate = src.borrow_rate(c)?;
            let effective_weight = (c.target_weight_bps as f64 / 10_000.0) * c.phase_in;
            weighted_sum += rate * effective_weight;
            total_weight += effective_weight;
        }

        if total_weight == 0.0 {
            return Err("no active constituents".to_string());
        }
        Ok(weighted_sum / total_weight)
    }
}

pub fn to_wad(rate: f64) -> u128 {
    (rate * 1e18) as u128
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sources::{Constituent, MockSource, Protocol};

    fn c(name: &str, bps: u16, phase: f64) -> Constituent {
        Constituent {
            name: name.to_string(),
            protocol: Protocol::Aave,
            target_weight_bps: bps,
            phase_in: phase,
        }
    }

    #[test]
    fn single_full_weight() {
        let idx = BenchmarkIndex::new(vec![c("a", 10_000, 1.0)]);
        let mut src = MockSource::default();
        src.set("a", 0.07);
        assert_eq!(idx.compute(&src).unwrap(), 0.07);
    }

    #[test]
    fn weighted_average() {
        let idx = BenchmarkIndex::new(vec![c("a", 6000, 1.0), c("b", 4000, 1.0)]);
        let mut src = MockSource::default();
        src.set("a", 0.06);
        src.set("b", 0.10);
        let r = idx.compute(&src).unwrap();
        assert!((r - 0.076).abs() < 1e-12);
    }

    #[test]
    fn phase_in_reduces_weight() {
        let idx = BenchmarkIndex::new(vec![c("a", 5000, 1.0), c("b", 5000, 0.0)]);
        let mut src = MockSource::default();
        src.set("a", 0.06);
        src.set("b", 0.20);
        assert_eq!(idx.compute(&src).unwrap(), 0.06);
    }

    #[test]
    fn empty_errors() {
        let idx = BenchmarkIndex::new(vec![]);
        let src = MockSource::default();
        assert!(idx.compute(&src).is_err());
    }

    #[test]
    fn wad_conversion() {
        let diff = to_wad(0.07) as i128 - 70_000_000_000_000_000i128;
        assert!(diff.abs() < 1_000);
    }
}
