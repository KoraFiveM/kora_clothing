-- qbclothing owns this schema only. Appearance/outfits have always been a
-- dedicated qb-clothing table (`playerskins`), never qbcore's per-citizen
-- `metadata` JSON blob -- qbcore's own compat stub for
-- `qb-multicharacter:server:getSkin` already names this exact table.

CREATE TABLE IF NOT EXISTS `playerskins` (
  `citizenid` VARCHAR(50) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `skin` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playeroutfits` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `outfitname` VARCHAR(50) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `skin` LONGTEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_playeroutfits_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
