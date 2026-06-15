CREATE DATABASE AccessControlSystem;
GO

USE AccessControlSystem;
GO

-- Таблица 1: Departments (Отделы)
CREATE TABLE Departments (
    department_id INT IDENTITY(1,1) PRIMARY KEY,
    department_code NVARCHAR(10) UNIQUE NOT NULL,
    department_name NVARCHAR(100) NOT NULL,
    parent_department_id INT NULL,
    created_date DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1
);
GO

-- Таблица 2: Employees (Сотрудники)
CREATE TABLE Employees (
    employee_id INT IDENTITY(1,1) PRIMARY KEY,
    card_uid NVARCHAR(32) UNIQUE NOT NULL,
    full_name NVARCHAR(100) NOT NULL,
    department_id INT NULL,
    position NVARCHAR(100),
    email NVARCHAR(100),
    phone NVARCHAR(20),
    work_start TIME DEFAULT '09:00',
    work_end TIME DEFAULT '18:00',
    hire_date DATE DEFAULT GETDATE(),
    termination_date DATE NULL,
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);
GO

-- Таблица 3: AccessPoints (Точки доступа)
CREATE TABLE AccessPoints (
    point_id INT IDENTITY(1,1) PRIMARY KEY,
    point_name NVARCHAR(100) NOT NULL,
    point_location NVARCHAR(200),
    point_type NVARCHAR(20) CHECK (point_type IN ('Main', 'Side', 'Emergency')),
    is_active BIT DEFAULT 1
);
GO

-- Таблица 4: Events (События) - ГЛАВНАЯ ТАБЛИЦА
CREATE TABLE Events (
    event_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    point_id INT NULL,
    event_time DATETIME NOT NULL,
    event_type SMALLINT NOT NULL CHECK (event_type IN (1, 2)), -- 1=Entry, 2=Exit
    access_granted BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE()
);
GO

-- Таблица 5: Violations (Нарушения)
CREATE TABLE Violations (
    violation_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    event_id BIGINT NOT NULL,
    employee_id INT NOT NULL,
    violation_type NVARCHAR(50) NOT NULL,
    violation_date DATE NOT NULL,
    violation_time TIME NOT NULL,
    severity INT DEFAULT 1 CHECK (severity IN (1, 2, 3)),
    description NVARCHAR(500),
    processed BIT DEFAULT 0,
    created_date DATETIME DEFAULT GETDATE()
);
GO

-- Таблица 6: WorkingHoursLog (Лог рабочего времени)
CREATE TABLE WorkingHoursLog (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    work_date DATE NOT NULL,
    entry_time DATETIME,
    exit_time DATETIME,
    hours_worked DECIMAL(5,2),
    overtime_hours DECIMAL(5,2),
    is_complete BIT DEFAULT 0,
    created_date DATETIME DEFAULT GETDATE()
);
GO

-- =====================================================
-- ДОБАВЛЯЕМ ВНЕШНИЕ КЛЮЧИ (ПОСЛЕ СОЗДАНИЯ ВСЕХ ТАБЛИЦ)
-- =====================================================

-- Связь Employees с Departments
ALTER TABLE Employees 
ADD CONSTRAINT FK_Employees_Departments 
FOREIGN KEY (department_id) REFERENCES Departments(department_id);
GO

-- Связь Events с Employees
ALTER TABLE Events 
ADD CONSTRAINT FK_Events_Employees 
FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);
GO

-- Связь Events с AccessPoints
ALTER TABLE Events 
ADD CONSTRAINT FK_Events_AccessPoints 
FOREIGN KEY (point_id) REFERENCES AccessPoints(point_id);
GO

-- Связь Violations с Events
ALTER TABLE Violations 
ADD CONSTRAINT FK_Violations_Events 
FOREIGN KEY (event_id) REFERENCES Events(event_id);
GO

-- Связь Violations с Employees
ALTER TABLE Violations 
ADD CONSTRAINT FK_Violations_Employees 
FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);
GO

-- Связь WorkingHoursLog с Employees
ALTER TABLE WorkingHoursLog 
ADD CONSTRAINT FK_WorkingHoursLog_Employees 
FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);
GO

PRINT 'Все таблицы и связи успешно созданы!';
GO