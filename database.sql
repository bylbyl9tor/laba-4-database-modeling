use warehouse;
drop table if EXISTS pharmacy;
CREATE TABLE pharmacy
(
    `id`       int PRIMARY KEY AUTO_INCREMENT,
    `name`     varchar(255),
    `phone`    varchar(50),
    `login`    varchar(20),
    `password` varchar(20)
);
drop table if exists order_position;
CREATE TABLE order_position
(
    `id`                int PRIMARY KEY AUTO_INCREMENT,
    `product_id`        int,
    `number_of_product` int,
    `medical_order_id`  int,
    `status`            enum ('OPEN','WORK','CLOSED')
);
ALTER TABLE `order_position` MODIFY COLUMN `status` enum ('OPEN','WORK','CLOSED') NOT NULL DEFAULT 'OPEN';
drop table if exists `pharmacy_order`;
CREATE TABLE `pharmacy_order`
(
    `id`                   int PRIMARY KEY AUTO_INCREMENT,
    `medical_id`           int,
    `order_position_count` int,
    `created_at`           TIMESTAMP DEFAULT now(),
    `status`               enum ('OPEN','RECEIVED')
);
ALTER TABLE `pharmacy_order` MODIFY COLUMN `status` enum ('OPEN','RECEIVED') NOT NULL DEFAULT 'OPEN';

drop table if exists `product`;
CREATE TABLE `product`
(
    `id`          int PRIMARY KEY AUTO_INCREMENT,
    `name`        varchar(255),
    `description` varchar(1000),
    `provider_id` int
);
drop table if exists pharmacy_warehouse;
CREATE TABLE pharmacy_warehouse
(
    `id`                           int PRIMARY KEY AUTO_INCREMENT,
    `product_id`                   int UNIQUE,
    `available_number_of_products` int,
    reserved_number_of_products    int
);

drop table if exists `providers`;
CREATE TABLE `providers`
(
    `id`   int PRIMARY KEY AUTO_INCREMENT,
    `name` varchar(50),
    `phone` varchar(50),
    `login`    varchar(20),
    `password` varchar(20)
);

ALTER TABLE pharmacy_order
    ADD FOREIGN KEY (`medical_id`) REFERENCES pharmacy (`id`);

ALTER TABLE `product`
    ADD FOREIGN KEY (`provider_id`) REFERENCES `providers` (`id`);

ALTER TABLE order_position
    ADD FOREIGN KEY (`product_id`) REFERENCES `product` (`id`);
ALTER TABLE order_position
    ADD FOREIGN KEY (`medical_order_id`) REFERENCES pharmacy_order (`id`);

ALTER TABLE pharmacy_warehouse
    ADD FOREIGN KEY (`product_id`) REFERENCES `product` (`id`);

-- когда вставляем позицию заказа
Drop TRIGGER if exists before_position_insert;
DELIMITER $$
CREATE TRIGGER before_position_insert
    BEFORE INSERT
    ON order_position
    FOR EACH ROW
BEGIN
    -- смотрит еслть ли свобод товары если есть то меняет статус
    IF ((select available_number_of_products
         from pharmacy_warehouse
         where product_id = new.product_id) > new.number_of_product) THEN
        update pharmacy_warehouse
        SET available_number_of_products = available_number_of_products - new.number_of_product,
            reserved_number_of_products  = reserved_number_of_products + new.number_of_product
        where product_id = new.product_id;
        SET new.status = 'CLOSED';
        IF ((select count(*)
             from order_position
             where medical_order_id = new.medical_order_id
            ) = (select order_position_count from pharmacy_order where id = new.medical_order_id) - 1) THEN
            update pharmacy_order
            SET status ='RECEIVED'
            where id = new.medical_order_id;
        end if;
    end if;
END$$
DELIMITER ;
-- когда поставщик поставил товар для заказа
Drop TRIGGER if exists update_medical_order_status;
DELIMITER $$
CREATE TRIGGER update_medical_order_status
    AFTER UPDATE
    ON order_position
    FOR EACH ROW
BEGIN
    IF (new.status = 'CLOSED') then
        update warehouse.pharmacy_warehouse
        set reserved_number_of_products = reserved_number_of_products + (
            select number_of_product
            from order_position
            where id = new.id)
        where product_id = new.product_id;
        IF ((select count(*)
             from order_position
             where medical_order_id = new.medical_order_id
               and status = 'CLOSED'
            ) = (select order_position_count from pharmacy_order where id = new.medical_order_id)) THEN
            update pharmacy_order
            SET status ='RECEIVED'
            where id = new.medical_order_id;
        end if;
    end if;
END$$
DELIMITER ;

# Drop TRIGGER if exists test;
# DELIMITER $$
# CREATE TRIGGER test
#     AFTER UPDATE
#     ON order_position
#     FOR EACH ROW
# BEGIN
#     insert into pharmacy(id, name) values (new.id + 10, new.product_id);
# END$$
# DELIMITER ;

-- создаёт запись на складе
Drop TRIGGER if exists add_new_product_warehouse;
DELIMITER $$
CREATE TRIGGER add_new_product_warehouse
    AFTER insert
    ON `product`
    FOR EACH ROW
BEGIN
    insert into warehouse.pharmacy_warehouse(product_id, available_number_of_products, reserved_number_of_products)
    values (new.id, 0, 0);
END$$
DELIMITER ;

-- delete num of product on warehouse
Drop TRIGGER if exists delete_order;
DELIMITER $$
CREATE TRIGGER delete_order
    BEFORE DELETE
    ON pharmacy_order
    FOR EACH ROW
BEGIN
    CALL warehouseUPDATE(old.id);
    DELETE from order_position where order_position.medical_order_id = old.id;
END$$
DELIMITER ;

Drop PROCEDURE if exists warehouseUPDATE;
CREATE PROCEDURE `warehouseUPDATE`(IN `orderID` INT(11))
    NO SQL
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE a, b, c, e, f INT;
    DECLARE cur1 CURSOR FOR SELECT * FROM order_position WHERE medical_order_id = orderID;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    OPEN cur1;
    read_loop:
    LOOP
        FETCH cur1 INTO a, b, c,e ,f;
        IF done THEN
            LEAVE read_loop;
        END IF;
        UPDATE pharmacy_warehouse
        SET reserved_number_of_products = reserved_number_of_products - c
        WHERE product_id = b;
    END LOOP;
    CLOSE cur1;
END;

ALTER TABLE order_position
    add constraint eee
        FOREIGN KEY (`medical_order_id`) REFERENCES pharmacy_order (`id`)
            on delete cascade;
ALTER TABLE warehouse.pharmacy_warehouse
    add constraint constr
        FOREIGN KEY (`product_id`) REFERENCES product (`id`)
            on delete cascade;

# Запустите это один раз для каждой схемы (замените database_name на имя схемы)
ALTER DATABASE warehouse CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

# Запустите это один раз для каждой таблицы (замените table_name именем таблицы)
ALTER TABLE pharmacy CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Выполните это для каждого столбца (замените имя таблицы, column_name, тип столбца, максимальную длину и т. д.)
ALTER TABLE pharmacy CHANGE name name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE providers CHANGE name name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE product CHANGE name name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE product CHANGE description description VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

