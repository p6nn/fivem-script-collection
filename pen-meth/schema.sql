
-- pen_meth_tables persistence schema
CREATE TABLE IF NOT EXISTS `pen_meth_tables` (
  `id` VARCHAR(64) NOT NULL PRIMARY KEY,
  `citizenid` VARCHAR(60) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL,
  `current_step` INT NOT NULL DEFAULT 1,
  `is_active` TINYINT(1) NOT NULL DEFAULT 0,
  `is_waiting` TINYINT(1) NOT NULL DEFAULT 0,
  `wait_end` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
