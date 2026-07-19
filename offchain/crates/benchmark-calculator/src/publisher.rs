pub struct HeartbeatPublisher {
    last_rate: f64,
    last_at: u64,
    published: bool,
    time_trigger_secs: u64,
    deviation_bps: f64,
}

impl HeartbeatPublisher {
    pub fn new(time_trigger_secs: u64, deviation_bps: f64) -> Self {
        Self {
            last_rate: 0.0,
            last_at: 0,
            published: false,
            time_trigger_secs,
            deviation_bps,
        }
    }

    pub fn should_publish(&self, now: u64, rate: f64) -> bool {
        if !self.published {
            return true;
        }
        let time_elapsed = now.saturating_sub(self.last_at) >= self.time_trigger_secs;
        let deviation = (rate - self.last_rate).abs() * 10_000.0;
        time_elapsed || deviation >= self.deviation_bps
    }

    pub fn record(&mut self, now: u64, rate: f64) {
        self.last_rate = rate;
        self.last_at = now;
        self.published = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_always_publishes() {
        let p = HeartbeatPublisher::new(43_200, 25.0);
        assert!(p.should_publish(0, 0.07));
    }

    #[test]
    fn time_trigger() {
        let mut p = HeartbeatPublisher::new(43_200, 25.0);
        p.record(1_000, 0.07);
        assert!(!p.should_publish(1_100, 0.07));
        assert!(p.should_publish(1_000 + 43_200, 0.07));
    }

    #[test]
    fn deviation_trigger() {
        let mut p = HeartbeatPublisher::new(43_200, 25.0);
        p.record(1_000, 0.0700);
        assert!(!p.should_publish(1_100, 0.0710));
        assert!(p.should_publish(1_100, 0.0730));
    }

    #[test]
    fn boundaries_trigger() {
        let mut p = HeartbeatPublisher::new(43_200, 25.0);
        p.record(1_000, 0.0700);
        assert!(p.should_publish(1_000 + 43_200, 0.0700));
        assert!(p.should_publish(1_001, 0.0726));
        assert!(!p.should_publish(1_001, 0.0724));
    }

    #[test]
    fn deviation_downward_triggers() {
        let mut p = HeartbeatPublisher::new(43_200, 25.0);
        p.record(1_000, 0.0700);
        assert!(p.should_publish(1_001, 0.0675));
    }
}
