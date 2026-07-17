#[derive(Clone, Copy)]
pub struct SwapPosition {
    pub id: u64,
    pub pay_fixed: bool,
    pub notional: f64,
    pub fixed_rate: f64,
    pub margin: f64,
    pub accumulator_at_open: f64,
    pub opened_at: u64,
    pub maturity: u64,
    pub maintenance_margin_bps: u16,
    pub settled: bool,
}

pub trait ChainClient {
    fn now(&self) -> u64;
    fn accumulator(&self) -> f64;
    fn open_positions(&self) -> Vec<SwapPosition>;
    fn settle(&self, id: u64);
    fn liquidate(&self, id: u64);
}

pub mod mock {
    use super::*;
    use std::cell::RefCell;

    pub struct MockChain {
        pub now: u64,
        pub accumulator: f64,
        pub positions: Vec<SwapPosition>,
        pub settled: RefCell<Vec<u64>>,
        pub liquidated: RefCell<Vec<u64>>,
    }

    impl MockChain {
        pub fn new(now: u64, accumulator: f64, positions: Vec<SwapPosition>) -> Self {
            Self {
                now,
                accumulator,
                positions,
                settled: RefCell::new(Vec::new()),
                liquidated: RefCell::new(Vec::new()),
            }
        }
    }

    impl ChainClient for MockChain {
        fn now(&self) -> u64 {
            self.now
        }
        fn accumulator(&self) -> f64 {
            self.accumulator
        }
        fn open_positions(&self) -> Vec<SwapPosition> {
            self.positions.clone()
        }
        fn settle(&self, id: u64) {
            self.settled.borrow_mut().push(id);
        }
        fn liquidate(&self, id: u64) {
            self.liquidated.borrow_mut().push(id);
        }
    }
}
