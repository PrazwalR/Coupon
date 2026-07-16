use benchmark_calculator::index::{to_wad, BenchmarkIndex};
use benchmark_calculator::publisher::HeartbeatPublisher;
use benchmark_calculator::sources::{Constituent, MockSource, Protocol};

fn main() {
    let constituents = vec![
        Constituent {
            name: "aave-usdc".into(),
            protocol: Protocol::Aave,
            target_weight_bps: 4000,
            phase_in: 1.0,
        },
        Constituent {
            name: "compound-usdc".into(),
            protocol: Protocol::Compound,
            target_weight_bps: 3000,
            phase_in: 1.0,
        },
        Constituent {
            name: "morpho-usdc".into(),
            protocol: Protocol::Morpho,
            target_weight_bps: 3000,
            phase_in: 1.0,
        },
    ];
    let index = BenchmarkIndex::new(constituents);

    let mut src = MockSource::default();
    src.set("aave-usdc", 0.070);
    src.set("compound-usdc", 0.065);
    src.set("morpho-usdc", 0.072);

    let rate = index.compute(&src).expect("compute index");
    let mut hb = HeartbeatPublisher::new(43_200, 25.0);
    let now = 0u64;
    if hb.should_publish(now, rate) {
        hb.record(now, rate);
        println!("index rate {:.6}  wad {}", rate, to_wad(rate));
    }
}
