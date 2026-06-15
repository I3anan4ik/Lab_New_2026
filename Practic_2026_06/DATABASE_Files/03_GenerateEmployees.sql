USE AccessControlSystem;
GO

-- =====================================================
-- ЗАПОЛНЕНИЕ ОТДЕЛОВ
-- =====================================================
INSERT INTO Departments (department_code, department_name, parent_department_id) VALUES
('IT', 'Информационные технологии', NULL),
('HR', 'Отдел кадров', NULL),
('SALES', 'Отдел продаж', NULL),
('LOG', 'Логистика', NULL),
('FIN', 'Финансовый отдел', NULL),
('MKT', 'Маркетинг', NULL),
('DEV', 'Отдел разработки', 1),
('SUP', 'Служба поддержки', 1),
('QA', 'Отдел тестирования', 1);
GO

-- =====================================================
-- ЗАПОЛНЕНИЕ ТОЧЕК ДОСТУПА
-- =====================================================
INSERT INTO AccessPoints (point_name, point_location, point_type) VALUES
('Главный вход', '1 этаж, центральный холл', 'Main'),
('Запасной выход', '1 этаж, восточное крыло', 'Side'),
('Служебный вход', 'Цокольный этаж', 'Side'),
('Аварийный выход', '2 этаж, западное крыло', 'Emergency'),
('Паркинг', 'Подземный паркинг', 'Side');
GO

-- =====================================================
-- ГЕНЕРАЦИЯ 1500+ СОТРУДНИКОВ
-- =====================================================
WITH NumberSequence AS (
    SELECT TOP 1500 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as n
    FROM sys.objects a 
    CROSS JOIN sys.objects b 
    CROSS JOIN sys.objects c
)
INSERT INTO Employees (card_uid, full_name, department_id, position, email, phone, work_start, work_end)
SELECT 
    -- Уникальный UID карты
    CONVERT(NVARCHAR(32), HASHBYTES('MD5', CAST(NEWID() AS NVARCHAR(36))), 2),
    
    -- ФИО
    CASE 
        WHEN n % 3 = 0 THEN 'Иван '
        WHEN n % 3 = 1 THEN 'Петр '
        ELSE 'Сергей '
    END + 
    CASE 
        WHEN n % 3 = 0 THEN 'Иванов'
        WHEN n % 3 = 1 THEN 'Петров'
        ELSE 'Сидоров'
    END,
    
    -- Отдел
    CASE (n % 9) + 1
        WHEN 1 THEN 1  -- IT
        WHEN 2 THEN 2  -- HR
        WHEN 3 THEN 3  -- SALES
        WHEN 4 THEN 4  -- LOG
        WHEN 5 THEN 5  -- FIN
        WHEN 6 THEN 6  -- MKT
        WHEN 7 THEN 7  -- DEV
        WHEN 8 THEN 8  -- SUP
        ELSE 9         -- QA
    END,
    
    -- Должность
    CASE (n % 5)
        WHEN 0 THEN 'Менеджер'
        WHEN 1 THEN 'Специалист'
        WHEN 2 THEN 'Инженер'
        WHEN 3 THEN 'Аналитик'
        ELSE 'Директор'
    END,
    
    -- Email
    'employee' + CAST(n AS NVARCHAR(10)) + '@company.com',
    
    -- Телефон
    '+7' + RIGHT('0000000000' + CAST(ABS(CHECKSUM(NEWID())) % 10000000000 AS NVARCHAR(10)), 10),
    
    -- Время работы (вариации)
    CASE (n % 4)
        WHEN 0 THEN '09:00'
        WHEN 1 THEN '08:00'
        WHEN 2 THEN '10:00'
        ELSE '09:30'
    END,
    
    CASE (n % 4)
        WHEN 0 THEN '18:00'
        WHEN 1 THEN '17:00'
        WHEN 2 THEN '19:00'
        ELSE '18:30'
    END
FROM NumberSequence;
GO

-- Проверка
SELECT 
    COUNT(*) as TotalEmployees,
    COUNT(DISTINCT department_id) as Departments,
    MIN(hire_date) as HireDateMin,
    MAX(hire_date) as HireDateMax
FROM Employees;
GO