use keeper::chain::mock::MockChain;
use keeper::chain::SwapPosition;
use keeper::engine::run_once;
use keeper::mark::SECONDS_PER_YEAR;

fn main() {
    let now = SECONDS_PER_YEAR as u64;
    let positions = vec![
        SwapPosition {
            id: 1,
            pay_fixed: true,
            notional: 1_000.0,
            fixed_rate: 0.20,
            margin: 100.0,
            accumulator_at_open: 1.0,
            opened_at: 0,
            maturity: now * 10,
            maintenance_margin_bps: 500,
            settled: false,
        },
        SwapPosition {
            id: 2,
            pay_fixed: true,
            notional: 1_000.0,
            fixed_rate: 0.05,
            margin: 100.0,
            accumulator_at_open: 1.0,
            opened_at: 0,
            maturity: now,
            maintenance_margin_bps: 500,
            settled: false,
        },
    ];

    let chain = MockChain::new(now, 1.10, positions);
    let actions = run_once(&chain);
    println!("liquidated {:?}  settled {:?}", actions.liquidated, actions.settled);
}
