-- Goals feature schema for business growth tracking
-- Allows resellers to set and track meaningful purchase targets
-- Run this after setup_db.py has created the orders table.

CREATE TABLE IF NOT EXISTS goals (
  id SERIAL PRIMARY KEY,
  customer_id VARCHAR(255) NOT NULL,
  title VARCHAR(200) NOT NULL,
  goal_type VARCHAR(50) NOT NULL, -- 'spending' | 'volume' | 'frequency' | 'exploration' | 'habit'
  target_value FLOAT NOT NULL,
  target_unit VARCHAR(50) NOT NULL, -- 'pesos' | 'units' | 'orders' | 'products' | 'weeks'
  is_autosuggest BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  is_completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMP,
  current_progress FLOAT DEFAULT 0,

  FOREIGN KEY (customer_id) REFERENCES orders(customer_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS goal_progress (
  id SERIAL PRIMARY KEY,
  goal_id INT NOT NULL,
  progress_value FLOAT NOT NULL,
  triggered_by_order_id VARCHAR(100),
  recorded_at TIMESTAMP DEFAULT NOW(),

  FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_goals_customer_id ON goals(customer_id);
CREATE INDEX IF NOT EXISTS idx_goals_is_completed ON goals(is_completed);
CREATE INDEX IF NOT EXISTS idx_goal_progress_goal_id ON goal_progress(goal_id);
