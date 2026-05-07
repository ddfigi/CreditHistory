

-- Вариант: Кредитная история — банки, заёмщики, поручители  (связи риска)
-- Узлы  (NODE): Bank, Borrower, Guarantor, Loan
-- Рёбра (EDGE): Issues, HasLoan, Guarantees, AssociatedWith
/*
============================================================
Created:  03.05.2026
Modified: 03.05.2026
Model:    Microsoft SQL Server 2022
Database: MS SQL Server 2022
Project:  Графовая база данных "Кредитная история"
============================================================
*/

-- ============================================================
-- СОЗДАНИЕ БАЗЫ ДАННЫХ
-- ============================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'CreditHistory')
BEGIN
    ALTER DATABASE CreditHistory SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CreditHistory;
END;
GO

CREATE DATABASE CreditHistory
    COLLATE Cyrillic_General_CI_AS;
GO

USE CreditHistory;
GO

-- ============================================================
-- ЧАСТЬ 1: СОЗДАНИЕ ТАБЛИЦ УЗЛОВ (NODE TABLES)
-- ============================================================

-- ------------------------------------------------------------
-- Таблица узлов: Bank (Банки)
-- bank_type: state | commercial | investment | cooperative
-- rating:    AAA | AA | A | BBB | BB | B | CCC
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Bank]
(
    [id]           INT            NOT NULL,
    [name]         NVARCHAR(100)  NOT NULL,
    [license_num]  NVARCHAR(20)   NOT NULL,
    [bank_type]    NVARCHAR(20)   NOT NULL
                   CONSTRAINT CK_Bank_type CHECK (
                       [bank_type] IN (N'state', N'commercial',
                                       N'investment', N'cooperative')),
    [rating]       NVARCHAR(5)    NOT NULL
                   CONSTRAINT CK_Bank_rating CHECK (
                       [rating] IN (N'AAA', N'AA', N'A',
                                    N'BBB', N'BB', N'B', N'CCC')),
    [founded_year] INT            NOT NULL,
    [city]         NVARCHAR(50)   NOT NULL,
    [total_assets_bln] DECIMAL(12,2) NOT NULL   -- активы, млрд руб.
)
AS NODE;
GO

ALTER TABLE [dbo].[Bank]
    ADD CONSTRAINT [PK_Bank] PRIMARY KEY ([id]);
GO

-- ------------------------------------------------------------
-- Таблица узлов: Borrower (Заёмщики)
-- borrower_type: individual | legal_entity
-- credit_score:  300–850 (аналог FICO)
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Borrower]
(
    [id]             INT            NOT NULL,
    [full_name]      NVARCHAR(100)  NOT NULL,
    [borrower_type]  NVARCHAR(15)   NOT NULL
                     CONSTRAINT CK_Borrower_type CHECK (
                         [borrower_type] IN (N'individual', N'legal_entity')),
    [inn]            NVARCHAR(12)   NOT NULL,          -- ИНН
    [credit_score]   INT            NOT NULL
                     CONSTRAINT CK_Borrower_score CHECK (
                         [credit_score] BETWEEN 300 AND 850),
    [income_monthly] DECIMAL(12,2)  NOT NULL,          -- руб/мес
    [city]           NVARCHAR(50)   NOT NULL,
    [reg_date]       DATE           NOT NULL            -- дата регистрации / рождения
)
AS NODE;
GO

ALTER TABLE [dbo].[Borrower]
    ADD CONSTRAINT [PK_Borrower] PRIMARY KEY ([id]);
GO

-- ------------------------------------------------------------
-- Таблица узлов: Guarantor (Поручители)
-- guarantor_type: individual | corporate | insurance
-- fin_status:     excellent | good | satisfactory | poor
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Guarantor]
(
    [id]             INT            NOT NULL,
    [full_name]      NVARCHAR(100)  NOT NULL,
    [guarantor_type] NVARCHAR(15)   NOT NULL
                     CONSTRAINT CK_Guarantor_type CHECK (
                         [guarantor_type] IN (N'individual',
                                              N'corporate', N'insurance')),
    [inn]            NVARCHAR(12)   NOT NULL,
    [fin_status]     NVARCHAR(15)   NOT NULL
                     CONSTRAINT CK_Guarantor_fin CHECK (
                         [fin_status] IN (N'excellent', N'good',
                                          N'satisfactory', N'poor')),
    [max_liability]  DECIMAL(14,2)  NOT NULL,          -- макс. сумма поручительства, руб.
    [city]           NVARCHAR(50)   NOT NULL
)
AS NODE;
GO

ALTER TABLE [dbo].[Guarantor]
    ADD CONSTRAINT [PK_Guarantor] PRIMARY KEY ([id]);
GO

-- ------------------------------------------------------------
-- Таблица узлов: Loan (Кредиты)
-- loan_type:   mortgage | consumer | auto | business | microfinance
-- loan_status: active | closed | default | restructured | overdue
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Loan]
(
    [id]             INT            NOT NULL,
    [loan_number]    NVARCHAR(20)   NOT NULL,           -- номер кредитного договора
    [loan_type]      NVARCHAR(15)   NOT NULL
                     CONSTRAINT CK_Loan_type CHECK (
                         [loan_type] IN (N'mortgage', N'consumer',
                                         N'auto', N'business',
                                         N'microfinance')),
    [amount]         DECIMAL(14,2)  NOT NULL,           -- сумма кредита, руб.
    [interest_rate]  DECIMAL(5,2)   NOT NULL,           -- ставка, % годовых
    [term_months]    INT            NOT NULL,           -- срок, мес.
    [loan_status]    NVARCHAR(15)   NOT NULL
                     CONSTRAINT CK_Loan_status CHECK (
                         [loan_status] IN (N'active', N'closed',
                                           N'default', N'restructured',
                                           N'overdue')),
    [issue_date]     DATE           NOT NULL,
    [close_date]     DATE           NULL,               -- NULL если ещё не закрыт
    [overdue_days]   INT            NOT NULL DEFAULT 0  -- дней просрочки
)
AS NODE;
GO

ALTER TABLE [dbo].[Loan]
    ADD CONSTRAINT [PK_Loan] PRIMARY KEY ([id]);
GO

-- ============================================================
-- ЧАСТЬ 2: СОЗДАНИЕ ТАБЛИЦ РЁБЕР (EDGE TABLES)
-- ============================================================

-- ------------------------------------------------------------
-- Ребро: Issues (Bank → Loan)
-- Банк выдал кредит.
-- approval_channel: branch | online | partner | phone
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Issues]
(
    [issue_date]        DATE          NOT NULL,
    [manager_name]      NVARCHAR(60)  NOT NULL,
    [approval_channel]  NVARCHAR(10)  NOT NULL
                        CONSTRAINT CK_Issues_channel CHECK (
                            [approval_channel] IN (N'branch', N'online',
                                                   N'partner', N'phone')),
    [branch_city]       NVARCHAR(50)  NOT NULL
)
AS EDGE;
GO

ALTER TABLE [dbo].[Issues]
    ADD CONSTRAINT [EC_Issues]
    CONNECTION ([Bank] TO [Loan]);
GO

-- ------------------------------------------------------------
-- Ребро: HasLoan (Borrower → Loan)
-- Заёмщик является стороной кредитного договора.
-- loan_purpose: purchase | refinancing | working_capital
--               | education | repair | other
-- ------------------------------------------------------------

CREATE TABLE [dbo].[HasLoan]
(
    [application_date]    DATE           NOT NULL,
    [loan_purpose]        NVARCHAR(20)   NOT NULL
                          CONSTRAINT CK_HasLoan_purpose CHECK (
                              [loan_purpose] IN (N'purchase', N'refinancing',
                                                 N'working_capital',
                                                 N'education', N'repair',
                                                 N'other')),
    [down_payment]        DECIMAL(14,2)  NOT NULL DEFAULT 0,  -- первоначальный взнос, руб.
    [monthly_payment]     DECIMAL(10,2)  NOT NULL             -- ежемесячный платёж, руб.
)
AS EDGE;
GO

ALTER TABLE [dbo].[HasLoan]
    ADD CONSTRAINT [EC_HasLoan]
    CONNECTION ([Borrower] TO [Loan]);
GO

-- ------------------------------------------------------------
-- Ребро: Guarantees (Guarantor → Loan)
-- Поручитель несёт ответственность по кредиту.
-- guarantee_type: full | partial | conditional
-- ------------------------------------------------------------

CREATE TABLE [dbo].[Guarantees]
(
    [contract_date]       DATE           NOT NULL,
    [guarantee_type]      NVARCHAR(15)   NOT NULL
                          CONSTRAINT CK_Guarantees_type CHECK (
                              [guarantee_type] IN (N'full', N'partial',
                                                   N'conditional')),
    [liability_amount]    DECIMAL(14,2)  NOT NULL,   
    [expiry_date]         DATE           NULL,       
    [is_active]           BIT            NOT NULL DEFAULT 1
)
AS EDGE;
GO

ALTER TABLE [dbo].[Guarantees]
    ADD CONSTRAINT [EC_Guarantees]
    CONNECTION ([Guarantor] TO [Loan]);
GO

-- ------------------------------------------------------------
-- Ребро: AssociatedWith (Borrower → Guarantor)
-- Связь заёмщика с поручителем (аффилированность, риск).
-- relation_type: relative | partner | employer | friend | unknown
-- ------------------------------------------------------------

CREATE TABLE [dbo].[AssociatedWith]
(
    [relation_type]    NVARCHAR(15)   NOT NULL
                       CONSTRAINT CK_AssociatedWith_rel CHECK (
                           [relation_type] IN (N'relative', N'partner',
                                               N'employer', N'friend',
                                               N'unknown')),
    [since_date]       DATE           NOT NULL,
    [risk_weight]      DECIMAL(4,2)   NOT NULL  
                       CONSTRAINT CK_AssociatedWith_risk CHECK (
                           [risk_weight] BETWEEN 0.00 AND 1.00),
    [verified]         BIT            NOT NULL DEFAULT 0  
)
AS EDGE;
GO

ALTER TABLE [dbo].[AssociatedWith]
    ADD CONSTRAINT [EC_AssociatedWith]
    CONNECTION ([Borrower] TO [Guarantor]);
GO

-- ============================================================
-- ЧАСТЬ 3: ЗАПОЛНЕНИЕ ТАБЛИЦ УЗЛОВ
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Данные: Bank (12 банков)
-- ------------------------------------------------------------

INSERT INTO [dbo].[Bank]
    (id, name, license_num, bank_type, rating, founded_year, city, total_assets_bln)
VALUES
    (1,  N'Сбербанк России',             N'1481',  N'state',       N'AAA', 1841, N'Москва',          37800.00),
    (2,  N'ВТБ',                         N'1000',  N'state',       N'AA',  1990, N'Санкт-Петербург',  20100.00),
    (3,  N'Газпромбанк',                 N'354',   N'state',       N'AA',  1990, N'Москва',           10500.00),
    (4,  N'Альфа-Банк',                  N'1326',  N'commercial',  N'A',   1990, N'Москва',            4800.00),
    (5,  N'Тинькофф Банк',               N'2673',  N'commercial',  N'A',   1994, N'Москва',            1980.00),
    (6,  N'Райффайзенбанк',              N'3292',  N'commercial',  N'A',   1996, N'Москва',            1560.00),
    (7,  N'Промсвязьбанк',               N'3251',  N'commercial',  N'BBB', 1995, N'Москва',            1750.00),
    (8,  N'Россельхозбанк',              N'3349',  N'state',       N'AA',  2000, N'Москва',            4100.00),
    (9,  N'Совкомбанк',                  N'963',   N'commercial',  N'BBB', 1990, N'Кострома',           950.00),
    (10, N'Банк Открытие',               N'2209',  N'commercial',  N'BBB', 1993, N'Москва',            2350.00),
    (11, N'МКБ (Московский кред. банк)', N'1978',  N'commercial',  N'BB',  1992, N'Москва',            1100.00),
    (12, N'Уральский банк реконструкции',N'429',   N'commercial',  N'BB',  1990, N'Екатеринбург',       430.00);
GO

-- ------------------------------------------------------------
-- 3.2 Данные: Borrower (15 заёмщиков)
-- ------------------------------------------------------------

INSERT INTO [dbo].[Borrower]
    (id, full_name, borrower_type, inn, credit_score, income_monthly, city, reg_date)
VALUES
    (1,  N'Иванов Сергей Николаевич',       N'individual',   N'771234567890', 720, 185000.00, N'Москва',          '1985-04-12'),
    (2,  N'Петрова Анна Михайловна',         N'individual',   N'781234567890', 680, 95000.00,  N'Санкт-Петербург', '1990-07-23'),
    (3,  N'ООО "СтройИнвест"',              N'legal_entity', N'7701234567',   640, 850000.00, N'Москва',          '2010-03-15'),
    (4,  N'Козлов Дмитрий Андреевич',        N'individual',   N'632345678901', 590, 62000.00,  N'Самара',          '1978-11-05'),
    (5,  N'Смирнова Екатерина Павловна',     N'individual',   N'783456789012', 750, 220000.00, N'Санкт-Петербург', '1992-02-18'),
    (6,  N'ИП Волков Андрей Геннадьевич',   N'legal_entity', N'6312345678',   610, 140000.00, N'Самара',          '2015-06-30'),
    (7,  N'Новиков Павел Игоревич',          N'individual',   N'504567890123', 480, 45000.00,  N'Подольск',        '1983-09-14'),
    (8,  N'Белова Ирина Олеговна',           N'individual',   N'785678901234', 800, 310000.00, N'Санкт-Петербург', '1988-12-01'),
    (9,  N'АО "ТехноГрупп"',               N'legal_entity', N'7809234567',   700, 2400000.00,N'Санкт-Петербург', '2005-09-20'),
    (10, N'Морозов Алексей Владимирович',    N'individual',   N'667890123456', 530, 55000.00,  N'Нижний Новгород', '1975-03-27'),
    (11, N'Соколова Наталья Сергеевна',      N'individual',   N'668901234567', 660, 78000.00,  N'Нижний Новгород', '1995-06-08'),
    (12, N'ООО "АгроПлюс"',                N'legal_entity', N'5612345678',   580, 680000.00, N'Самара',          '2012-01-22'),
    (13, N'Зайцев Роман Викторович',         N'individual',   N'773456789012', 430, 38000.00,  N'Москва',          '1980-10-15'),
    (14, N'Лебедева Юлия Константиновна',    N'individual',   N'774567890123', 710, 165000.00, N'Москва',          '1993-05-29'),
    (15, N'ПАО "МегаСтрой"',               N'legal_entity', N'7712345678',   670, 3200000.00,N'Москва',          '2003-11-11');
GO

-- ------------------------------------------------------------
-- 3.3 Данные: Guarantor (12 поручителей)
-- ------------------------------------------------------------

INSERT INTO [dbo].[Guarantor]
    (id, full_name, guarantor_type, inn, fin_status, max_liability, city)
VALUES
    (1,  N'Иванова Татьяна Николаевна',      N'individual',  N'772345678901', N'good',         3000000.00, N'Москва'),
    (2,  N'Громов Виктор Степанович',         N'individual',  N'783456789012', N'excellent',    8000000.00, N'Санкт-Петербург'),
    (3,  N'ООО "КапиталГарант"',            N'corporate',   N'7703456789',   N'excellent',   50000000.00, N'Москва'),
    (4,  N'СК "Надёжность"',               N'insurance',   N'7704567890',   N'excellent',  100000000.00, N'Москва'),
    (5,  N'Козлова Светлана Дмитриевна',      N'individual',  N'634567890123', N'satisfactory', 1500000.00, N'Самара'),
    (6,  N'Попов Андрей Николаевич',          N'individual',  N'785678901234', N'good',         5000000.00, N'Санкт-Петербург'),
    (7,  N'АО "ФинансПартнёр"',             N'corporate',   N'7806789012',   N'good',        30000000.00, N'Санкт-Петербург'),
    (8,  N'Волкова Марина Игоревна',          N'individual',  N'506789012345', N'satisfactory', 1000000.00, N'Подольск'),
    (9,  N'Семёнов Игорь Борисович',          N'individual',  N'669012345678', N'poor',          500000.00, N'Нижний Новгород'),
    (10, N'ООО "АгроГарант"',               N'corporate',   N'5678901234',   N'good',        20000000.00, N'Самара'),
    (11, N'Медведев Константин Романович',    N'individual',  N'775678901234', N'good',         6000000.00, N'Москва'),
    (12, N'СК "ГлобалСтрах"',              N'insurance',   N'7712345679',   N'excellent',  200000000.00, N'Москва');
GO

-- ------------------------------------------------------------
-- 3.4 Данные: Loan (18 кредитов)
-- ------------------------------------------------------------

INSERT INTO [dbo].[Loan]
    (id, loan_number, loan_type, amount, interest_rate, term_months,
     loan_status, issue_date, close_date, overdue_days)
VALUES
    (1,  N'СБ-2021-001',  N'mortgage',     8500000.00, 8.50,  240, N'active',       '2021-03-15', NULL,         0),
    (2,  N'ВТБ-2020-045', N'mortgage',     6200000.00, 9.20,  180, N'active',       '2020-08-20', NULL,         0),
    (3,  N'ГПБ-2022-112', N'business',    15000000.00, 11.00, 60,  N'active',       '2022-01-10', NULL,         0),
    (4,  N'АЛФ-2019-078', N'consumer',     1200000.00, 16.50, 36,  N'closed',       '2019-05-12', '2022-05-12', 0),
    (5,  N'ТИН-2023-201', N'auto',         2800000.00, 14.00, 60,  N'active',       '2023-02-28', NULL,         0),
    (6,  N'СБ-2018-330',  N'mortgage',    12000000.00, 10.25, 300, N'restructured', '2018-06-01', NULL,        90),
    (7,  N'РАЙ-2022-067', N'business',     5000000.00, 12.50, 36,  N'default',      '2022-07-15', NULL,       365),
    (8,  N'ПСБ-2021-099', N'consumer',      850000.00, 18.00, 24,  N'overdue',      '2021-11-30', NULL,        45),
    (9,  N'РСХ-2020-156', N'business',    25000000.00, 9.80,  84,  N'active',       '2020-04-05', NULL,         0),
    (10, N'СОВ-2023-044', N'consumer',      450000.00, 22.00, 18,  N'active',       '2023-06-10', NULL,         0),
    (11, N'МКБ-2019-211', N'auto',         1900000.00, 15.00, 48,  N'closed',       '2019-09-01', '2023-09-01', 0),
    (12, N'УБР-2021-033', N'consumer',      300000.00, 24.00, 12,  N'default',      '2021-01-20', NULL,       480),
    (13, N'СБ-2022-445',  N'mortgage',     9800000.00, 8.80,  360, N'active',       '2022-10-01', NULL,         0),
    (14, N'ВТБ-2023-187', N'business',    40000000.00, 10.50, 120, N'active',       '2023-05-15', NULL,         0),
    (15, N'АЛФ-2020-310', N'consumer',     2100000.00, 17.50, 36,  N'overdue',      '2020-12-01', NULL,        62),
    (16, N'ТИН-2022-089', N'microfinance',   150000.00, 29.00, 12,  N'default',      '2022-03-10', NULL,       210),
    (17, N'ГПБ-2021-277', N'business',    18000000.00, 11.50, 72,  N'active',       '2021-08-25', NULL,         0),
    (18, N'РАЙ-2023-114', N'mortgage',     7300000.00, 9.00,  240, N'active',       '2023-09-20', NULL,         0);
GO

-- ============================================================
-- ЧАСТЬ 4: ЗАПОЛНЕНИЕ ТАБЛИЦ РЁБЕР
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Issues: Bank → Loan
-- Какой банк выдал какой кредит
-- ------------------------------------------------------------
-- Сбербанк:        Loan 1, 6, 13
-- ВТБ:             Loan 2, 14
-- Газпромбанк:     Loan 3, 17
-- Альфа-Банк:      Loan 4, 15
-- Тинькофф:        Loan 5, 16
-- Райффайзенбанк:  Loan 7, 18
-- Промсвязьбанк:   Loan 8
-- Россельхозбанк:  Loan 9
-- Совкомбанк:      Loan 10
-- МКБ:             Loan 11
-- УБРиР:           Loan 12
-- ------------------------------------------------------------

INSERT INTO [dbo].[Issues] ($from_id, $to_id, issue_date, manager_name, approval_channel, branch_city)
VALUES
    -- Сбербанк выдал ипотеку Loan 1
    ((SELECT $node_id FROM Bank WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 1),
     '2021-03-15', N'Орлова Елена Васильевна', N'branch', N'Москва'),
    -- Сбербанк выдал реструктурированную ипотеку Loan 6
    ((SELECT $node_id FROM Bank WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 6),
     '2018-06-01', N'Фролов Игорь Петрович', N'branch', N'Москва'),
    -- Сбербанк выдал ипотеку Loan 13
    ((SELECT $node_id FROM Bank WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 13),
     '2022-10-01', N'Крылова Ирина Алексеевна', N'online', N'Москва'),
    -- ВТБ выдал ипотеку Loan 2
    ((SELECT $node_id FROM Bank WHERE id = 2),
     (SELECT $node_id FROM Loan WHERE id = 2),
     '2020-08-20', N'Соболев Денис Игоревич', N'branch', N'Санкт-Петербург'),
    -- ВТБ выдал бизнес-кредит Loan 14
    ((SELECT $node_id FROM Bank WHERE id = 2),
     (SELECT $node_id FROM Loan WHERE id = 14),
     '2023-05-15', N'Козырев Антон Борисович', N'branch', N'Санкт-Петербург'),
    -- Газпромбанк выдал бизнес-кредит Loan 3
    ((SELECT $node_id FROM Bank WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 3),
     '2022-01-10', N'Лыков Степан Фёдорович', N'partner', N'Москва'),
    -- Газпромбанк выдал бизнес-кредит Loan 17
    ((SELECT $node_id FROM Bank WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 17),
     '2021-08-25', N'Тарасов Роман Кириллович', N'branch', N'Москва'),
    -- Альфа-Банк выдал потребкредит Loan 4 (закрыт)
    ((SELECT $node_id FROM Bank WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 4),
     '2019-05-12', N'Власова Надежда Сергеевна', N'online', N'Москва'),
    -- Альфа-Банк выдал просроченный потребкредит Loan 15
    ((SELECT $node_id FROM Bank WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 15),
     '2020-12-01', N'Климов Вадим Леонидович', N'online', N'Москва'),
    -- Тинькофф выдал автокредит Loan 5
    ((SELECT $node_id FROM Bank WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 5),
     '2023-02-28', N'Жуков Аркадий Николаевич', N'online', N'Москва'),
    -- Тинькофф выдал микрокредит Loan 16 (дефолт)
    ((SELECT $node_id FROM Bank WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 16),
     '2022-03-10', N'Жуков Аркадий Николаевич', N'online', N'Москва'),
    -- Райффайзенбанк выдал бизнес-кредит Loan 7 (дефолт)
    ((SELECT $node_id FROM Bank WHERE id = 6),
     (SELECT $node_id FROM Loan WHERE id = 7),
     '2022-07-15', N'Бауэр Михаил Вильгельмович', N'branch', N'Москва'),
    -- Райффайзенбанк выдал ипотеку Loan 18
    ((SELECT $node_id FROM Bank WHERE id = 6),
     (SELECT $node_id FROM Loan WHERE id = 18),
     '2023-09-20', N'Бауэр Михаил Вильгельмович', N'branch', N'Санкт-Петербург'),
    -- Промсвязьбанк выдал просроченный потребкредит Loan 8
    ((SELECT $node_id FROM Bank WHERE id = 7),
     (SELECT $node_id FROM Loan WHERE id = 8),
     '2021-11-30', N'Никитин Олег Романович', N'branch', N'Москва'),
    -- Россельхозбанк выдал бизнес-кредит Loan 9
    ((SELECT $node_id FROM Bank WHERE id = 8),
     (SELECT $node_id FROM Loan WHERE id = 9),
     '2020-04-05', N'Аграрникова Зоя Ивановна', N'branch', N'Санкт-Петербург'),
    -- Совкомбанк выдал потребкредит Loan 10
    ((SELECT $node_id FROM Bank WHERE id = 9),
     (SELECT $node_id FROM Loan WHERE id = 10),
     '2023-06-10', N'Митрофанов Евгений Витальевич', N'online', N'Кострома'),
    -- МКБ выдал автокредит Loan 11 (закрыт)
    ((SELECT $node_id FROM Bank WHERE id = 11),
     (SELECT $node_id FROM Loan WHERE id = 11),
     '2019-09-01', N'Савельев Михаил Дмитриевич', N'branch', N'Москва'),
    -- УБРиР выдал дефолтный потребкредит Loan 12
    ((SELECT $node_id FROM Bank WHERE id = 12),
     (SELECT $node_id FROM Loan WHERE id = 12),
     '2021-01-20', N'Ершова Людмила Павловна', N'phone', N'Екатеринбург');
GO

-- ------------------------------------------------------------
-- 4.2 HasLoan: Borrower → Loan
-- Какой заёмщик взял какой кредит
-- ------------------------------------------------------------
-- Иванов С.Н.    (1): Loan 1 (ипотека СБ), Loan 4 (потребит. Альфа — закрыт)
-- Петрова А.М.   (2): Loan 2 (ипотека ВТБ)
-- ООО СтройИнвест(3): Loan 3 (бизнес ГПБ), Loan 7 (бизнес Рай — дефолт)
-- Козлов Д.А.    (4): Loan 8 (потребит. ПСБ — просрочка), Loan 12 (потребит. УБРиР — дефолт)
-- Смирнова Е.П.  (5): Loan 5 (авто ТКФ), Loan 13 (ипотека СБ)
-- ИП Волков А.Г. (6): Loan 6 (ипотека СБ — реструктур.), Loan 15 (потребит. Альфа — просрочка)
-- Новиков П.И.   (7): Loan 16 (микро ТКФ — дефолт)
-- Белова И.О.    (8): Loan 18 (ипотека Рай)
-- АО ТехноГрупп  (9): Loan 9 (бизнес РСХ), Loan 14 (бизнес ВТБ)
-- Морозов А.В.   (10): Loan 10 (потребит. СОВ), Loan 11 (авто МКБ — закрыт)
-- Соколова Н.С.  (11): Loan 15 (у неё нет — пропускаем), добавим отдельный
-- Зайцев Р.В.    (13): Loan 12 (дефолт, ещё и Козлов — созаёмщик, добавим второй)
-- Лебедева Ю.К.  (14): Loan 17 (бизнес ГПБ — через компанию), нет, добавим потребит.
-- ПАО МегаСтрой  (15): Loan 17 (бизнес ГПБ)
-- ------------------------------------------------------------

INSERT INTO [dbo].[HasLoan] ($from_id, $to_id, application_date, loan_purpose, down_payment, monthly_payment)
VALUES
    -- Иванов → Loan 1 (ипотека)
    ((SELECT $node_id FROM Borrower WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 1),
     '2021-02-20', N'purchase', 1500000.00, 75000.00),
    -- Иванов → Loan 4 (потребит., закрыт)
    ((SELECT $node_id FROM Borrower WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 4),
     '2019-04-25', N'repair', 0.00, 42000.00),
    -- Петрова → Loan 2 (ипотека)
    ((SELECT $node_id FROM Borrower WHERE id = 2),
     (SELECT $node_id FROM Loan WHERE id = 2),
     '2020-07-30', N'purchase', 1200000.00, 58000.00),
    -- ООО СтройИнвест → Loan 3 (бизнес)
    ((SELECT $node_id FROM Borrower WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 3),
     '2021-12-15', N'working_capital', 0.00, 340000.00),
    -- ООО СтройИнвест → Loan 7 (бизнес, дефолт)
    ((SELECT $node_id FROM Borrower WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 7),
     '2022-06-20', N'working_capital', 0.00, 180000.00),
    -- Козлов → Loan 8 (потребит., просрочка)
    ((SELECT $node_id FROM Borrower WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 8),
     '2021-11-01', N'other', 0.00, 43000.00),
    -- Козлов → Loan 12 (потребит., дефолт)
    ((SELECT $node_id FROM Borrower WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 12),
     '2020-12-28', N'other', 0.00, 28000.00),
    -- Смирнова → Loan 5 (авто)
    ((SELECT $node_id FROM Borrower WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 5),
     '2023-02-10', N'purchase', 700000.00, 62000.00),
    -- Смирнова → Loan 13 (ипотека)
    ((SELECT $node_id FROM Borrower WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 13),
     '2022-09-01', N'purchase', 2000000.00, 84000.00),
    -- ИП Волков → Loan 6 (ипотека, реструктур.)
    ((SELECT $node_id FROM Borrower WHERE id = 6),
     (SELECT $node_id FROM Loan WHERE id = 6),
     '2018-05-10', N'purchase', 2000000.00, 112000.00),
    -- ИП Волков → Loan 15 (потребит., просрочка)
    ((SELECT $node_id FROM Borrower WHERE id = 6),
     (SELECT $node_id FROM Loan WHERE id = 15),
     '2020-11-15', N'other', 0.00, 77000.00),
    -- Новиков → Loan 16 (микро, дефолт)
    ((SELECT $node_id FROM Borrower WHERE id = 7),
     (SELECT $node_id FROM Loan WHERE id = 16),
     '2022-02-28', N'other', 0.00, 15000.00),
    -- Белова → Loan 18 (ипотека)
    ((SELECT $node_id FROM Borrower WHERE id = 8),
     (SELECT $node_id FROM Loan WHERE id = 18),
     '2023-08-25', N'purchase', 1500000.00, 67000.00),
    -- АО ТехноГрупп → Loan 9 (бизнес)
    ((SELECT $node_id FROM Borrower WHERE id = 9),
     (SELECT $node_id FROM Loan WHERE id = 9),
     '2020-03-10', N'working_capital', 0.00, 380000.00),
    -- АО ТехноГрупп → Loan 14 (бизнес ВТБ)
    ((SELECT $node_id FROM Borrower WHERE id = 9),
     (SELECT $node_id FROM Loan WHERE id = 14),
     '2023-04-20', N'working_capital', 0.00, 510000.00),
    -- Морозов → Loan 10 (потребит.)
    ((SELECT $node_id FROM Borrower WHERE id = 10),
     (SELECT $node_id FROM Loan WHERE id = 10),
     '2023-05-25', N'repair', 0.00, 29000.00),
    -- Морозов → Loan 11 (авто, закрыт)
    ((SELECT $node_id FROM Borrower WHERE id = 10),
     (SELECT $node_id FROM Loan WHERE id = 11),
     '2019-08-10', N'purchase', 400000.00, 50000.00),
    -- ПАО МегаСтрой → Loan 17 (бизнес ГПБ)
    ((SELECT $node_id FROM Borrower WHERE id = 15),
     (SELECT $node_id FROM Loan WHERE id = 17),
     '2021-08-01', N'working_capital', 0.00, 420000.00);
GO

-- ------------------------------------------------------------
-- 4.3 Guarantees: Guarantor → Loan
-- Кто поручается по каким кредитам
-- ------------------------------------------------------------
-- Иванова Т.Н.     (1)  → Loan 1 (полная)
-- Громов В.С.      (2)  → Loan 2 (полная), Loan 13 (частичная)
-- КапиталГарант    (3)  → Loan 3 (полная), Loan 9 (условная)
-- СК Надёжность    (4)  → Loan 6 (полная), Loan 14 (условная)
-- Козлова С.Д.     (5)  → Loan 8 (частичная), Loan 12 (частичная)
-- Попов А.Н.       (6)  → Loan 5 (полная)
-- ФинансПартнёр    (7)  → Loan 7 (полная — дефолт), Loan 17 (условная)
-- Волкова М.И.     (8)  → Loan 15 (частичная)
-- Семёнов И.Б.     (9)  → Loan 16 (частичная — дефолт)
-- АгроГарант      (10)  → Loan 9 (дополнительная)
-- Медведев К.Р.   (11)  → Loan 18 (полная)
-- ГлобалСтрах     (12)  → Loan 14 (страховая часть)
-- ------------------------------------------------------------

INSERT INTO [dbo].[Guarantees] ($from_id, $to_id, contract_date, guarantee_type, liability_amount, expiry_date, is_active)
VALUES
    -- Иванова → Loan 1 (полная гарантия, ипотека)
    ((SELECT $node_id FROM Guarantor WHERE id = 1),
     (SELECT $node_id FROM Loan WHERE id = 1),
     '2021-03-10', N'full', 8500000.00, '2041-03-10', 1),
    -- Громов → Loan 2 (полная гарантия)
    ((SELECT $node_id FROM Guarantor WHERE id = 2),
     (SELECT $node_id FROM Loan WHERE id = 2),
     '2020-08-15', N'full', 6200000.00, '2037-08-15', 1),
    -- Громов → Loan 13 (частичная)
    ((SELECT $node_id FROM Guarantor WHERE id = 2),
     (SELECT $node_id FROM Loan WHERE id = 13),
     '2022-09-25', N'partial', 4900000.00, '2052-09-25', 1),
    -- КапиталГарант → Loan 3 (полная, бизнес)
    ((SELECT $node_id FROM Guarantor WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 3),
     '2022-01-05', N'full', 15000000.00, '2027-01-05', 1),
    -- КапиталГарант → Loan 9 (условная, бизнес)
    ((SELECT $node_id FROM Guarantor WHERE id = 3),
     (SELECT $node_id FROM Loan WHERE id = 9),
     '2020-03-25', N'conditional', 12000000.00, '2027-04-05', 1),
    -- СК Надёжность → Loan 6 (полная, реструктур.)
    ((SELECT $node_id FROM Guarantor WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 6),
     '2018-05-25', N'full', 12000000.00, '2043-06-01', 1),
    -- СК Надёжность → Loan 14 (условная, бизнес)
    ((SELECT $node_id FROM Guarantor WHERE id = 4),
     (SELECT $node_id FROM Loan WHERE id = 14),
     '2023-05-10', N'conditional', 20000000.00, '2033-05-15', 1),
    -- Козлова → Loan 8 (частичная, просрочка)
    ((SELECT $node_id FROM Guarantor WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 8),
     '2021-11-25', N'partial', 500000.00, '2023-11-25', 0),  -- истёк
    -- Козлова → Loan 12 (частичная, дефолт)
    ((SELECT $node_id FROM Guarantor WHERE id = 5),
     (SELECT $node_id FROM Loan WHERE id = 12),
     '2021-01-15', N'partial', 300000.00, '2022-01-15', 0),  -- истёк
    -- Попов → Loan 5 (полная, авто)
    ((SELECT $node_id FROM Guarantor WHERE id = 6),
     (SELECT $node_id FROM Loan WHERE id = 5),
     '2023-02-25', N'full', 2800000.00, '2028-02-28', 1),
    -- ФинансПартнёр → Loan 7 (полная, дефолт — поручитель под риском)
    ((SELECT $node_id FROM Guarantor WHERE id = 7),
     (SELECT $node_id FROM Loan WHERE id = 7),
     '2022-07-10', N'full', 5000000.00, '2025-07-15', 1),
    -- ФинансПартнёр → Loan 17 (условная, бизнес)
    ((SELECT $node_id FROM Guarantor WHERE id = 7),
     (SELECT $node_id FROM Loan WHERE id = 17),
     '2021-08-20', N'conditional', 9000000.00, '2027-08-25', 1),
    -- Волкова → Loan 15 (частичная, просрочка)
    ((SELECT $node_id FROM Guarantor WHERE id = 8),
     (SELECT $node_id FROM Loan WHERE id = 15),
     '2020-11-25', N'partial', 700000.00, '2023-12-01', 0),  -- истёк
    -- Семёнов → Loan 16 (частичная, дефолт)
    ((SELECT $node_id FROM Guarantor WHERE id = 9),
     (SELECT $node_id FROM Loan WHERE id = 16),
     '2022-03-05', N'partial', 100000.00, '2023-03-10', 0),  -- истёк
    -- АгроГарант → Loan 9 (условная, дополнительная гарантия по бизнес-кредиту)
    ((SELECT $node_id FROM Guarantor WHERE id = 10),
     (SELECT $node_id FROM Loan WHERE id = 9),
     '2020-04-01', N'conditional', 8000000.00, '2027-04-05', 1),
    -- Медведев → Loan 18 (полная, ипотека)
    ((SELECT $node_id FROM Guarantor WHERE id = 11),
     (SELECT $node_id FROM Loan WHERE id = 18),
     '2023-09-15', N'full', 7300000.00, '2043-09-20', 1),
    -- ГлобалСтрах → Loan 14 (страховая часть, крупный бизнес-кредит)
    ((SELECT $node_id FROM Guarantor WHERE id = 12),
     (SELECT $node_id FROM Loan WHERE id = 14),
     '2023-05-12', N'partial', 40000000.00, '2033-05-15', 1);
GO

-- ------------------------------------------------------------
-- 4.4 AssociatedWith: Borrower → Guarantor
-- Связи аффилированности (для анализа концентрации риска)
-- ------------------------------------------------------------
-- Иванов (1) → Иванова (1): родственник (жена)
-- Петрова (2) → Громов (2): друг
-- ООО СтройИнвест (3) → КапиталГарант (3): партнёр (аффилированные)
-- Козлов (4) → Козлова (5): родственник (сестра)
-- Козлов (4) → Семёнов (9): друг
-- Смирнова (5) → Громов (2): друг
-- ИП Волков (6) → Волкова (8): родственник
-- Новиков (7) → Семёнов (9): друг (риск-кластер)
-- Белова (8) → Медведев (11): партнёр
-- АО ТехноГрупп (9) → ФинансПартнёр (7): партнёр (аффилированные)
-- АО ТехноГрупп (9) → КапиталГарант (3): работодатель
-- Морозов (10) → Семёнов (9): друг
-- ПАО МегаСтрой (15) → ФинансПартнёр (7): партнёр
-- ------------------------------------------------------------

INSERT INTO [dbo].[AssociatedWith] ($from_id, $to_id, relation_type, since_date, risk_weight, verified)
VALUES
    -- Иванов → Иванова (супруги)
    ((SELECT $node_id FROM Borrower WHERE id = 1),
     (SELECT $node_id FROM Guarantor WHERE id = 1),
     N'relative', '2012-08-25', 0.90, 1),
    -- Петрова → Громов (друг)
    ((SELECT $node_id FROM Borrower WHERE id = 2),
     (SELECT $node_id FROM Guarantor WHERE id = 2),
     N'friend', '2018-01-10', 0.40, 1),
    -- ООО СтройИнвест → КапиталГарант (партнёр, аффилиация)
    ((SELECT $node_id FROM Borrower WHERE id = 3),
     (SELECT $node_id FROM Guarantor WHERE id = 3),
     N'partner', '2015-03-20', 0.85, 1),
    -- Козлов → Козлова (родственник, сестра)
    ((SELECT $node_id FROM Borrower WHERE id = 4),
     (SELECT $node_id FROM Guarantor WHERE id = 5),
     N'relative', '1978-11-05', 0.80, 1),
    -- Козлов → Семёнов (друг, общий риск-кластер)
    ((SELECT $node_id FROM Borrower WHERE id = 4),
     (SELECT $node_id FROM Guarantor WHERE id = 9),
     N'friend', '2005-06-15', 0.35, 0),
    -- Смирнова → Громов (друг)
    ((SELECT $node_id FROM Borrower WHERE id = 5),
     (SELECT $node_id FROM Guarantor WHERE id = 2),
     N'friend', '2015-09-01', 0.30, 1),
    -- ИП Волков → Волкова (родственник, жена)
    ((SELECT $node_id FROM Borrower WHERE id = 6),
     (SELECT $node_id FROM Guarantor WHERE id = 8),
     N'relative', '2014-05-20', 0.90, 1),
    -- Новиков → Семёнов (друг, оба в проблемных кредитах)
    ((SELECT $node_id FROM Borrower WHERE id = 7),
     (SELECT $node_id FROM Guarantor WHERE id = 9),
     N'friend', '2010-03-12', 0.40, 0),
    -- Белова → Медведев (партнёр по бизнесу)
    ((SELECT $node_id FROM Borrower WHERE id = 8),
     (SELECT $node_id FROM Guarantor WHERE id = 11),
     N'partner', '2019-11-15', 0.60, 1),
    -- АО ТехноГрупп → ФинансПартнёр (аффилированные структуры)
    ((SELECT $node_id FROM Borrower WHERE id = 9),
     (SELECT $node_id FROM Guarantor WHERE id = 7),
     N'partner', '2012-07-01', 0.95, 1),
    -- АО ТехноГрупп → КапиталГарант (работодатель — учредитель)
    ((SELECT $node_id FROM Borrower WHERE id = 9),
     (SELECT $node_id FROM Guarantor WHERE id = 3),
     N'employer', '2005-09-20', 0.70, 1),
    -- Морозов → Семёнов (общий знакомый, неверифицированная связь)
    ((SELECT $node_id FROM Borrower WHERE id = 10),
     (SELECT $node_id FROM Guarantor WHERE id = 9),
     N'unknown', '2020-01-01', 0.20, 0),
    -- ПАО МегаСтрой → ФинансПартнёр (аффилированные структуры)
    ((SELECT $node_id FROM Borrower WHERE id = 15),
     (SELECT $node_id FROM Guarantor WHERE id = 7),
     N'partner', '2018-04-10', 0.90, 1);
GO

-- ============================================================
-- ПРОВЕРКА: количество строк во всех таблицах
-- ============================================================

SELECT N'Bank'            AS [Таблица], COUNT(*) AS [Строк] FROM Bank
UNION ALL SELECT N'Borrower',           COUNT(*) FROM Borrower
UNION ALL SELECT N'Guarantor',          COUNT(*) FROM Guarantor
UNION ALL SELECT N'Loan',               COUNT(*) FROM Loan
UNION ALL SELECT N'Issues',             COUNT(*) FROM Issues
UNION ALL SELECT N'HasLoan',            COUNT(*) FROM HasLoan
UNION ALL SELECT N'Guarantees',         COUNT(*) FROM Guarantees
UNION ALL SELECT N'AssociatedWith',     COUNT(*) FROM AssociatedWith;
GO

-- ============================================================
-- ЧАСТЬ 5: ЗАПРОСЫ MATCH (6 запросов, цепочки 3+ узлов)
-- ============================================================

-- ------------------------------------------------------------
-- Запрос 1: Полная цепочка риска по каждому кредиту
-- Банк выдал кредит → заёмщик взял кредит → поручитель гарантировал
-- Цепочка: Bank → (Issues) → Loan ← (HasLoan) ← Borrower
--          + Guarantor → (Guarantees) → Loan (JOIN)
-- ------------------------------------------------------------
PRINT N'=== Запрос 1: Полная цепочка риска — банк, кредит, заёмщик, поручитель ===';
SELECT
    b.name              AS [Банк],
    b.rating            AS [Рейтинг банка],
    l.loan_number       AS [Номер договора],
    l.loan_type         AS [Тип кредита],
    l.amount            AS [Сумма, руб.],
    l.loan_status       AS [Статус],
    br.full_name        AS [Заёмщик],
    br.credit_score     AS [Кред. рейтинг],
    g.full_name         AS [Поручитель],
    gu.guarantee_type   AS [Тип поручительства],
    gu.liability_amount AS [Сумма ответств., руб.]
FROM Bank        AS b
   , Issues      AS iss
   , Loan        AS l
   , HasLoan     AS hl
   , Borrower    AS br
   , Guarantees  AS gu
   , Guarantor   AS g
WHERE MATCH(b-(iss)->l<-(hl)-br)
  AND MATCH(g-(gu)->l)
ORDER BY l.loan_status DESC, l.amount DESC;
GO

-- ------------------------------------------------------------
-- Запрос 2: Проблемные кредиты — дефолт и просрочка
-- с поручителями, которые несут активную ответственность
-- Цепочка: Borrower → (HasLoan) → Loan ← (Guarantees) ← Guarantor
-- ------------------------------------------------------------
PRINT N'=== Запрос 2: Проблемные кредиты и ответственные поручители ===';
SELECT
    br.full_name          AS [Заёмщик],
    br.credit_score       AS [Скоринг],
    l.loan_number         AS [Договор],
    l.loan_type           AS [Тип],
    l.loan_status         AS [Статус],
    l.overdue_days        AS [Дней просрочки],
    l.amount              AS [Сумма долга, руб.],
    g.full_name           AS [Поручитель],
    g.fin_status          AS [Фин. статус поручителя],
    gu.guarantee_type     AS [Тип гарантии],
    gu.liability_amount   AS [Сумма ответств., руб.],
    gu.is_active          AS [Гарантия активна]
FROM Borrower   AS br
   , HasLoan    AS hl
   , Loan       AS l
   , Guarantees AS gu
   , Guarantor  AS g
WHERE MATCH(br-(hl)->l<-(gu)-g)
  AND l.loan_status IN (N'default', N'overdue')
ORDER BY l.overdue_days DESC;
GO

-- ------------------------------------------------------------
-- Запрос 3: Банки с заёмщиками низкого кредитного рейтинга (< 600)
-- Оценка качества кредитного портфеля по банку
-- Цепочка: Bank → (Issues) → Loan ← (HasLoan) ← Borrower
-- ------------------------------------------------------------
PRINT N'=== Запрос 3: Банки и заёмщики с кредитным рейтингом ниже 600 ===';
SELECT
    b.name                AS [Банк],
    b.rating              AS [Рейтинг банка],
    b.bank_type           AS [Тип банка],
    br.full_name          AS [Заёмщик],
    br.credit_score       AS [Скоринг заёмщика],
    br.borrower_type      AS [Тип заёмщика],
    l.loan_number         AS [Договор],
    l.loan_type           AS [Тип кредита],
    l.amount              AS [Сумма, руб.],
    l.interest_rate       AS [Ставка, %],
    l.loan_status         AS [Статус]
FROM Bank      AS b
   , Issues    AS iss
   , Loan      AS l
   , HasLoan   AS hl
   , Borrower  AS br
WHERE MATCH(b-(iss)->l<-(hl)-br)
  AND br.credit_score < 600
ORDER BY br.credit_score ASC, l.amount DESC;
GO

-- ------------------------------------------------------------
-- Запрос 4: Аффилированные заёмщики — цепочка:
-- Borrower → (AssociatedWith) → Guarantor + Guarantor → (Guarantees) → Loan
-- Поиск концентрации риска: аффилированные связи с высоким risk_weight
-- Цепочка 4 узла: Borrower → Guarantor → Loan ← Bank
-- ------------------------------------------------------------
PRINT N'=== Запрос 4: Концентрация риска — аффилированные заёмщики и их гарантируемые кредиты ===';
SELECT
    br.full_name        AS [Заёмщик],
    br.credit_score     AS [Скоринг],
    aw.relation_type    AS [Тип связи],
    aw.risk_weight      AS [Коэф. риска],
    aw.verified         AS [Связь верифицирована],
    g.full_name         AS [Поручитель],
    g.fin_status        AS [Фин. статус],
    l.loan_number       AS [Гарантируемый договор],
    l.loan_type         AS [Тип кредита],
    l.loan_status       AS [Статус кредита],
    l.amount            AS [Сумма, руб.],
    gu.guarantee_type   AS [Тип гарантии],
    gu.is_active        AS [Гарантия активна]
FROM Borrower      AS br
   , AssociatedWith AS aw
   , Guarantor      AS g
   , Guarantees     AS gu
   , Loan           AS l
WHERE MATCH(br-(aw)->g-(gu)->l)
  AND aw.risk_weight >= 0.70
ORDER BY aw.risk_weight DESC, br.full_name;
GO

-- ------------------------------------------------------------
-- Запрос 5: Поручители под двойной нагрузкой —
-- гарантируют несколько кредитов хотя бы один из которых проблемный
-- Цепочка: Guarantor → (Guarantees) → Loan ← (HasLoan) ← Borrower
-- + фильтр по поручителям, которые встречаются несколько раз
-- ------------------------------------------------------------
PRINT N'=== Запрос 5: Поручители с несколькими гарантиями, включая проблемные кредиты ===';
SELECT
    g.full_name           AS [Поручитель],
    g.guarantor_type      AS [Тип поручителя],
    g.fin_status          AS [Фин. статус],
    g.max_liability       AS [Макс. ответств., руб.],
    COUNT(l.id)
        OVER (PARTITION BY g.id) AS [Кол-во гарантий],
    SUM(gu.liability_amount)
        OVER (PARTITION BY g.id) AS [Итого ответств., руб.],
    l.loan_number         AS [Договор],
    l.loan_status         AS [Статус кредита],
    l.amount              AS [Сумма кредита, руб.],
    br.full_name          AS [Заёмщик],
    gu.guarantee_type     AS [Тип гарантии],
    gu.is_active          AS [Активна]
FROM Guarantor   AS g
   , Guarantees  AS gu
   , Loan        AS l
   , HasLoan     AS hl
   , Borrower    AS br
WHERE MATCH(g-(gu)->l<-(hl)-br)
  AND g.id IN (
        -- поручители, у которых больше одной гарантии
        SELECT g2.id
        FROM Guarantor   AS g2
           , Guarantees  AS gu2
           , Loan        AS l2
        WHERE MATCH(g2-(gu2)->l2)
        GROUP BY g2.id
        HAVING COUNT(*) > 1
      )
ORDER BY g.full_name, l.loan_status;
GO

-- ------------------------------------------------------------
-- Запрос 6 (бонусный): Банки, чьи кредиты обеспечены
-- поручителями с плохим финансовым статусом ("poor" / "satisfactory")
-- 4-звенная цепочка: Bank → Loan ← Guarantor + Guarantor.fin_status
-- ------------------------------------------------------------
PRINT N'=== Запрос 6 (бонус): Кредиты с ненадёжными поручителями по банку ===';
SELECT
    b.name             AS [Банк],
    b.rating           AS [Рейтинг банка],
    l.loan_number      AS [Договор],
    l.loan_type        AS [Тип кредита],
    l.amount           AS [Сумма, руб.],
    l.interest_rate    AS [Ставка, %],
    l.loan_status      AS [Статус],
    g.full_name        AS [Поручитель],
    g.fin_status       AS [Фин. статус поручителя],
    gu.guarantee_type  AS [Тип гарантии],
    gu.liability_amount AS [Сумма ответств., руб.],
    br.full_name       AS [Заёмщик],
    br.credit_score    AS [Скоринг заёмщика]
FROM Bank       AS b
   , Issues     AS iss
   , Loan       AS l
   , Guarantees AS gu
   , Guarantor  AS g
   , HasLoan    AS hl
   , Borrower   AS br
WHERE MATCH(b-(iss)->l<-(gu)-g)
  AND MATCH(br-(hl)->l)
  AND g.fin_status IN (N'poor', N'satisfactory')
ORDER BY b.name, l.amount DESC;
GO

-- ============================================================
-- ЧАСТЬ 6: ЗАПРОСЫ SHORTEST_PATH
-- ============================================================
-- ------------------------------------------------------------
-- SP-Запрос 1: Все пути от поручителя к кредитам через гарантии
-- Шаблон "+": 1 и более гарантий (глубина рекурсии)
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 1: Цепочки гарантий от поручителя — шаблон + ===';
SELECT
    g1.full_name  AS [Поручитель],
    STRING_AGG(l.loan_number, ' -> ')
        WITHIN GROUP (GRAPH PATH)     AS [Путь по договорам],
    COUNT(l.loan_number)
        WITHIN GROUP (GRAPH PATH)     AS [Глубина пути],
    LAST_VALUE(l.loan_number)
        WITHIN GROUP (GRAPH PATH)     AS [Последний договор],
    LAST_VALUE(l.loan_status)
        WITHIN GROUP (GRAPH PATH)     AS [Статус последнего]
FROM Guarantor      AS g1
   , Guarantees     FOR PATH AS gu
   , Loan           FOR PATH AS l
WHERE MATCH(SHORTEST_PATH(g1(-(gu)->l)+))
ORDER BY g1.full_name, [Глубина пути];
GO

-- ------------------------------------------------------------
-- SP-Запрос 2: Кратчайший путь от конкретного поручителя
-- до кредитов в статусе default/overdue
-- Шаблон "+": ищем все пути, фильтруем конечный узел
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 2: Кратчайший путь от КапиталГарант до проблемных кредитов ===';
WITH PathCTE AS
(
    SELECT
        g1.full_name  AS [Поручитель],
        STRING_AGG(l.loan_number, ' -> ')
            WITHIN GROUP (GRAPH PATH)  AS [Путь],
        COUNT(l.loan_number)
            WITHIN GROUP (GRAPH PATH)  AS [Длина],
        LAST_VALUE(l.loan_number)
            WITHIN GROUP (GRAPH PATH)  AS [Конечный договор],
        LAST_VALUE(l.loan_status)
            WITHIN GROUP (GRAPH PATH)  AS [Конечный статус]
    FROM Guarantor  AS g1
       , Guarantees FOR PATH AS gu
       , Loan       FOR PATH AS l
    WHERE MATCH(SHORTEST_PATH(g1(-(gu)->l)+))
      AND g1.full_name = N'ООО "КапиталГарант"'
)
SELECT
    [Поручитель],
    [Путь],
    [Длина],
    [Конечный договор],
    [Конечный статус]
FROM PathCTE
WHERE [Конечный статус] IN (N'default', N'overdue', N'restructured')
ORDER BY [Длина];
GO

-- ------------------------------------------------------------
-- SP-Запрос 3: Все цепочки гарантий глубиной от 1 до 3 шагов
-- Шаблон "{1,3}" — ограничение глубины обхода
-- Позволяет найти: один поручитель → один кредит (1 шаг),
-- или транзитивные связи если несколько гарантий подряд (2-3 шага)
-- ------------------------------------------------------------
PRINT N'=== SP-Запрос 3: Все пути гарантирования глубиной 1–3 шага, шаблон {1,3} ===';
SELECT
    g1.full_name     AS [Поручитель],
    g1.guarantor_type AS [Тип поручителя],
    STRING_AGG(l.loan_number, ' -> ')
        WITHIN GROUP (GRAPH PATH)   AS [Цепочка договоров],
    COUNT(l.loan_number)
        WITHIN GROUP (GRAPH PATH)   AS [Длина цепочки],
    LAST_VALUE(l.loan_number)
        WITHIN GROUP (GRAPH PATH)   AS [Последний договор],
    LAST_VALUE(l.loan_status)
        WITHIN GROUP (GRAPH PATH)   AS [Статус конечного],
    LAST_VALUE(l.amount)
        WITHIN GROUP (GRAPH PATH)   AS [Сумма конечного, руб.]
FROM Guarantor  AS g1
   , Guarantees FOR PATH AS gu
   , Loan       FOR PATH AS l
WHERE MATCH(SHORTEST_PATH(g1(-(gu)->l){1,3}))
ORDER BY g1.full_name, [Длина цепочки];
GO
