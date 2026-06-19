CREATE TABLE IF NOT EXISTS `JorgeDev_businesses` (
  `id` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `category` VARCHAR(50) NOT NULL,
  `description` TEXT NOT NULL,
  `x` FLOAT NOT NULL,
  `y` FLOAT NOT NULL,
  `isOpen` TINYINT(1) NOT NULL DEFAULT 1,
  `owner` VARCHAR(100) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `job` VARCHAR(50) NOT NULL DEFAULT '',
  `createdAt` BIGINT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `JorgeDev_business_reviews` (
  `id` VARCHAR(50) NOT NULL,
  `businessId` VARCHAR(50) NOT NULL,
  `author` VARCHAR(100) NOT NULL,
  `rating` INT NOT NULL,
  `comment` TEXT NOT NULL,
  `createdAt` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_jorgedev_business_reviews` FOREIGN KEY (`businessId`) REFERENCES `JorgeDev_businesses`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `JorgeDev_business_events` (
  `id` VARCHAR(50) NOT NULL,
  `businessId` VARCHAR(50) NOT NULL,
  `title` VARCHAR(100) NOT NULL,
  `time` VARCHAR(100) NOT NULL,
  `description` TEXT NOT NULL,
  `image` TEXT,
  `isActive` TINYINT(1) NOT NULL DEFAULT 1,
  `price` VARCHAR(50) NOT NULL DEFAULT 'Gratis',
  `location` VARCHAR(100) NOT NULL DEFAULT '',
  `requirements` VARCHAR(100) NOT NULL DEFAULT '',
  `createdAt` BIGINT NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_jorgedev_business_events` FOREIGN KEY (`businessId`) REFERENCES `JorgeDev_businesses`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
