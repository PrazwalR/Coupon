use crate::chain::ChainClient;
use crate::mark::mark_position;

pub struct Actions {
    pub settled: Vec<u64>,
    pub liquidated: Vec<u64>,
}

pub fn run_once<C: ChainClient>(client: &C) -> Actions {
    let acc = client.accumulator();
    let now = client.now();
    let mut settled = Vec::new();
    let mut liquidated = Vec::new();

    for pos in client.open_positions() {
        if pos.settled {
            continue;
        }
        let health = mark_position(&pos, acc, now);
        if health.liquidatable {
            client.liquidate(pos.id);
            liquidated.push(pos.id);
        } else if now >= pos.maturity {
            client.settle(pos.id);
            settled.push(pos.id);
        }
    }

    Actions { settled, liquidated }
}

pub fn run_forever<C: ChainClient>(client: &C, interval_secs: u64) -> ! {
    loop {
        run_once(client);
        std::thread::sleep(std::time::Duration::from_secs(interval_secs));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::chain::mock::MockChain;
    use crate::chain::SwapPosition;
    use crate::mark::SECONDS_PER_YEAR;

    fn base(id: u64, fixed: f64, maturity: u64, settled: bool) -> SwapPosition {
        SwapPosition {
            id,
            pay_fixed: true,
            notional: 1_000.0,
            fixed_rate: fixed,
            margin: 100.0,
            accumulator_at_open: 1.0,
            opened_at: 0,
            maturity,
            maintenance_margin_bps: 500,
            settled,
        }
    }

    #[test]
    fn liquidates_underwater_settles_matured_skips_rest() {
        let now = SECONDS_PER_YEAR as u64;
        let positions = vec![
            base(1, 0.20, now * 10, false),
            base(2, 0.05, now, false),
            base(3, 0.05, now * 10, false),
            base(4, 0.05, now, true),
        ];
        let chain = MockChain::new(now, 1.10, positions);
        let actions = run_once(&chain);

        assert_eq!(actions.liquidated, vec![1]);
        assert_eq!(actions.settled, vec![2]);
        assert_eq!(*chain.liquidated.borrow(), vec![1]);
        assert_eq!(*chain.settled.borrow(), vec![2]);
    }

    #[test]
    fn multiple_underwater_all_liquidated() {
        let now = SECONDS_PER_YEAR as u64;
        let positions = vec![
            base(1, 0.20, now * 10, false),
            base(2, 0.25, now * 10, false),
            base(3, 0.05, now * 10, false),
        ];
        let chain = MockChain::new(now, 1.10, positions);
        let actions = run_once(&chain);
        assert_eq!(actions.liquidated, vec![1, 2]);
        assert!(actions.settled.is_empty());
    }

    #[test]
    fn matured_and_liquidatable_prioritizes_liquidation() {
        let now = SECONDS_PER_YEAR as u64;
        let positions = vec![base(1, 0.30, now, false)];
        let chain = MockChain::new(now, 1.05, positions);
        let actions = run_once(&chain);
        assert_eq!(actions.liquidated, vec![1]);
        assert!(actions.settled.is_empty());
    }

    #[test]
    fn empty_positions_no_actions() {
        let chain = MockChain::new(1000, 1.0, vec![]);
        let actions = run_once(&chain);
        assert!(actions.liquidated.is_empty());
        assert!(actions.settled.is_empty());
    }
}
