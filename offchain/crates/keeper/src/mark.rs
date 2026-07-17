use crate::chain::SwapPosition;

pub const SECONDS_PER_YEAR: f64 = 365.0 * 24.0 * 3600.0;

pub struct PositionHealth {
    pub position_id: u64,
    pub pnl: f64,
    pub equity: f64,
    pub liquidatable: bool,
}

pub fn mark_position(pos: &SwapPosition, accumulator_now: f64, now: u64) -> PositionHealth {
    let floating_return = accumulator_now / pos.accumulator_at_open - 1.0;
    let elapsed = now.saturating_sub(pos.opened_at) as f64;
    let fixed_accrual = pos.fixed_rate * elapsed / SECONDS_PER_YEAR;

    let leg_diff = floating_return - fixed_accrual;
    let pnl_fraction = if pos.pay_fixed { leg_diff } else { -leg_diff };
    let pnl = pnl_fraction * pos.notional;

    let equity = pos.margin + pnl;
    let maintenance = pos.notional * pos.maintenance_margin_bps as f64 / 10_000.0;

    PositionHealth {
        position_id: pos.id,
        pnl,
        equity,
        liquidatable: equity < maintenance,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pos() -> SwapPosition {
        SwapPosition {
            id: 1,
            pay_fixed: true,
            notional: 1_000.0,
            fixed_rate: 0.07,
            margin: 100.0,
            accumulator_at_open: 1.0,
            opened_at: 0,
            maturity: SECONDS_PER_YEAR as u64,
            maintenance_margin_bps: 500,
            settled: false,
        }
    }

    #[test]
    fn payfixed_gains_when_floating_rises() {
        let p = pos();
        let h = mark_position(&p, 1.10, SECONDS_PER_YEAR as u64);
        assert!(h.pnl > 0.0);
        assert!((h.pnl - 30.0).abs() < 1e-6);
        assert!(!h.liquidatable);
    }

    #[test]
    fn payfixed_underwater_when_floating_low() {
        let p = pos();
        let h = mark_position(&p, 1.01, SECONDS_PER_YEAR as u64);
        assert!(h.pnl < 0.0);
        assert!(h.equity < 50.0);
        assert!(h.liquidatable);
    }

    #[test]
    fn receivefixed_is_mirror() {
        let mut p = pos();
        p.pay_fixed = false;
        let h = mark_position(&p, 1.10, SECONDS_PER_YEAR as u64);
        assert!(h.pnl < 0.0);
    }
}
