#include <iostream>
#include <windows.h>
#include <sql.h>
#include <sqlext.h>
#include <chrono>
#include <string>

using namespace std;

// Строка подключения - ИЗМЕНИТЕ НА ВАШУ!
const wstring CONNECTION_STRING = L"Driver={ODBC Driver 17 for SQL Server};Server=DESKTOP-TK7GI2K\\I3ANAN4IK;Database=AccessControlSystem;Trusted_Connection=yes;";

// Функция для вывода ошибок SQL
void PrintSQLError(SQLHANDLE handle, SQLSMALLINT handleType) {
    SQLWCHAR sqlState[1024];
    SQLWCHAR message[1024];
    SQLINTEGER nativeError;
    SQLSMALLINT textLength;

    SQLGetDiagRec(handleType, handle, 1, sqlState, &nativeError, message, sizeof(message), &textLength);

    wcout << L"[ОШИБКА SQL] " << message << L" (State: " << sqlState << L")" << endl;
}

// Подключение к базе данных
SQLHDBC ConnectToDatabase() {
    SQLHENV henv;
    SQLHDBC hdbc;
    SQLRETURN ret;

    ret = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &henv);
    if (!SQL_SUCCEEDED(ret)) return nullptr;

    ret = SQLSetEnvAttr(henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER)SQL_OV_ODBC3, 0);
    if (!SQL_SUCCEEDED(ret)) return nullptr;

    ret = SQLAllocHandle(SQL_HANDLE_DBC, henv, &hdbc);
    if (!SQL_SUCCEEDED(ret)) return nullptr;

    ret = SQLDriverConnect(hdbc, NULL, (SQLWCHAR*)CONNECTION_STRING.c_str(), SQL_NTS, NULL, 0, NULL, SQL_DRIVER_COMPLETE);
    if (!SQL_SUCCEEDED(ret)) {
        PrintSQLError(hdbc, SQL_HANDLE_DBC);
        return nullptr;
    }

    return hdbc;
}

// Регистрация события
bool RegisterEvent(SQLHDBC hdbc, int employeeId, int eventType) {
    SQLHSTMT hstmt;
    SQLRETURN ret;

    ret = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);
    if (!SQL_SUCCEEDED(ret)) return false;

    wchar_t sql[512];
    swprintf(sql, 512, L"INSERT INTO Events (employee_id, point_id, event_time, event_type, access_granted) VALUES (%d, 1, GETDATE(), %d, 1)", employeeId, eventType);

    ret = SQLExecDirect(hstmt, sql, SQL_NTS);
    SQLFreeHandle(SQL_HANDLE_STMT, hstmt);

    return SQL_SUCCEEDED(ret);
}

// 1. Статистика прихода и ухода
void ShowStatistics(SQLHDBC hdbc) {
    cout << "\n================================================================================" << endl;
    cout << "СТАТИСТИКА ПРИХОДА И УХОДА (последние 30 дней)" << endl;
    cout << "================================================================================" << endl;

    auto start = chrono::high_resolution_clock::now();

    SQLHSTMT hstmt;
    SQLRETURN ret;

    ret = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);
    if (!SQL_SUCCEEDED(ret)) return;

    const wchar_t* sql = L"SELECT FORMAT(ev.event_time, 'yyyy-MM-dd'), COUNT(CASE WHEN ev.event_type = 1 THEN 1 END), COUNT(CASE WHEN ev.event_type = 2 THEN 1 END) FROM Events ev WHERE ev.event_time > DATEADD(DAY, -30, GETDATE()) GROUP BY FORMAT(ev.event_time, 'yyyy-MM-dd') ORDER BY 1 DESC";

    ret = SQLExecDirect(hstmt, (SQLWCHAR*)sql, SQL_NTS);

    if (SQL_SUCCEEDED(ret)) {
        cout << "\n+------------+----------+----------+" << endl;
        cout << "|    Дата    |  Входы   |  Выходы  |" << endl;
        cout << "+------------+----------+----------+" << endl;

        int totalEntries = 0, totalExits = 0;
        SQLWCHAR date[20];
        int entries, exits;

        while (SQLFetch(hstmt) == SQL_SUCCESS) {
            SQLGetData(hstmt, 1, SQL_C_WCHAR, date, sizeof(date), NULL);
            SQLGetData(hstmt, 2, SQL_C_SLONG, &entries, 0, NULL);
            SQLGetData(hstmt, 3, SQL_C_SLONG, &exits, 0, NULL);
            totalEntries += entries;
            totalExits += exits;

            wstring wdate(date);
            string sdate(wdate.begin(), wdate.end());
            cout << "| " << sdate.substr(0, 10) << " | " << entries << "       | " << exits << "       |" << endl;
        }
        cout << "+------------+----------+----------+" << endl;
        cout << "| ИТОГО:     | " << totalEntries << "       | " << totalExits << "       |" << endl;
        cout << "+------------+----------+----------+" << endl;
    }

    SQLFreeHandle(SQL_HANDLE_STMT, hstmt);

    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(end - start);
    cout << "\n[Время] Выполнения: " << duration.count() << " мс" << endl;
}

// 2. Нарушители по датам
void ShowViolatorsByDate(SQLHDBC hdbc) {
    cout << "\n================================================================================" << endl;
    cout << "НАРУШИТЕЛИ ПО ДАТАМ (последние 90 дней)" << endl;
    cout << "================================================================================" << endl;

    auto start = chrono::high_resolution_clock::now();

    SQLHSTMT hstmt;
    SQLRETURN ret;

    ret = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);
    if (!SQL_SUCCEEDED(ret)) return;

    const wchar_t* sql = L"SELECT TOP 20 e.full_name, FORMAT(v.violation_date, 'yyyy-MM-dd'), COUNT(*), v.violation_type FROM Violations v INNER JOIN Employees e ON v.employee_id = e.employee_id WHERE v.violation_date > DATEADD(DAY, -90, GETDATE()) GROUP BY e.full_name, FORMAT(v.violation_date, 'yyyy-MM-dd'), v.violation_type ORDER BY COUNT(*) DESC";

    ret = SQLExecDirect(hstmt, (SQLWCHAR*)sql, SQL_NTS);

    if (SQL_SUCCEEDED(ret)) {
        cout << "\n+--------------------------------+------------+----------+-----------------+" << endl;
        cout << "|           Сотрудник            |    Дата    |  Кол-во  |      Тип        |" << endl;
        cout << "+--------------------------------+------------+----------+-----------------+" << endl;

        SQLWCHAR name[100], date[20], type[50];
        int count;

        while (SQLFetch(hstmt) == SQL_SUCCESS) {
            SQLGetData(hstmt, 1, SQL_C_WCHAR, name, sizeof(name), NULL);
            SQLGetData(hstmt, 2, SQL_C_WCHAR, date, sizeof(date), NULL);
            SQLGetData(hstmt, 3, SQL_C_SLONG, &count, 0, NULL);
            SQLGetData(hstmt, 4, SQL_C_WCHAR, type, sizeof(type), NULL);

            wstring wname(name);
            wstring wdate(date);
            wstring wtype(type);
            string sname(wname.begin(), wname.end());
            string sdate(wdate.begin(), wdate.end());
            string stype(wtype.begin(), wtype.end());

            cout << "| " << sname.substr(0, 30) << string(30 - min(30, (int)sname.length()), ' ');
            cout << " | " << sdate << " | " << count << "       | " << stype.substr(0, 15) << " |" << endl;
        }
        cout << "+--------------------------------+------------+----------+-----------------+" << endl;
    }

    SQLFreeHandle(SQL_HANDLE_STMT, hstmt);

    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(end - start);
    cout << "\n[Время] Выполнения: " << duration.count() << " мс" << endl;
}

// 3. Нарушители по периодам
void ShowViolatorsByPeriod(SQLHDBC hdbc) {
    cout << "\n================================================================================" << endl;
    cout << "НАРУШИТЕЛИ ПО ПЕРИОДАМ" << endl;
    cout << "================================================================================" << endl;

    struct Period { const char* name; int days; };
    Period periods[] = { {"Месяц", -30}, {"Квартал", -90}, {"Год", -365} };

    for (const auto& period : periods) {
        cout << "\n--- " << period.name << " ---" << endl;

        SQLHSTMT hstmt;
        SQLRETURN ret;

        ret = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);
        if (!SQL_SUCCEEDED(ret)) continue;

        wchar_t sql[512];
        swprintf(sql, 512, L"SELECT TOP 10 e.full_name, COUNT(*), v.violation_type FROM Violations v INNER JOIN Employees e ON v.employee_id = e.employee_id WHERE v.violation_date > DATEADD(DAY, %d, GETDATE()) GROUP BY e.full_name, v.violation_type ORDER BY COUNT(*) DESC", period.days);

        ret = SQLExecDirect(hstmt, sql, SQL_NTS);

        if (SQL_SUCCEEDED(ret)) {
            cout << "+--------------------------------+----------+-----------------+" << endl;
            cout << "|           Сотрудник            |  Кол-во  |      Тип        |" << endl;
            cout << "+--------------------------------+----------+-----------------+" << endl;

            SQLWCHAR name[100], type[50];
            int count;

            while (SQLFetch(hstmt) == SQL_SUCCESS) {
                SQLGetData(hstmt, 1, SQL_C_WCHAR, name, sizeof(name), NULL);
                SQLGetData(hstmt, 2, SQL_C_SLONG, &count, 0, NULL);
                SQLGetData(hstmt, 3, SQL_C_WCHAR, type, sizeof(type), NULL);

                wstring wname(name);
                wstring wtype(type);
                string sname(wname.begin(), wname.end());
                string stype(wtype.begin(), wtype.end());

                cout << "| " << sname.substr(0, 30) << string(30 - min(30, (int)sname.length()), ' ');
                cout << " | " << count << "       | " << stype.substr(0, 15) << " |" << endl;
            }
            cout << "+--------------------------------+----------+-----------------+" << endl;
        }

        SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
    }
}

// 4. ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок) - упрощенная версия
void PerformanceTest(SQLHDBC hdbc) {
    cout << "\n================================================================================" << endl;
    cout << "ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок)" << endl;
    cout << "================================================================================" << endl;

    auto start = chrono::high_resolution_clock::now();

    for (int i = 1; i <= 1000; i++) {
        int empId = (i % 1000) + 1;
        int eventType = (i % 2) + 1;
        RegisterEvent(hdbc, empId, eventType);
    }

    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(end - start);

    cout << "\n[РЕЗУЛЬТАТЫ ТЕСТА]:" << endl;
    cout << "   Время выполнения: " << duration.count() << " мс" << endl;
    cout << "   Среднее время на вставку: " << duration.count() / 1000.0 << " мс" << endl;
}

// 5. Полная аналитика
void FullAnalytics(SQLHDBC hdbc) {
    cout << "\n================================================================================" << endl;
    cout << "ПОЛНАЯ АНАЛИТИКА НАРУШЕНИЙ" << endl;
    cout << "================================================================================" << endl;

    SQLHSTMT hstmt;
    SQLRETURN ret;

    ret = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);
    if (!SQL_SUCCEEDED(ret)) return;

    const wchar_t* sql = L"SELECT (SELECT COUNT(DISTINCT employee_id) FROM Violations), (SELECT COUNT(*) FROM Violations), (SELECT COUNT(*) FROM Events), (SELECT COUNT(*) FROM Employees)";

    ret = SQLExecDirect(hstmt, (SQLWCHAR*)sql, SQL_NTS);

    if (SQL_SUCCEEDED(ret) && SQLFetch(hstmt) == SQL_SUCCESS) {
        int violators, totalViolations, totalEvents, totalEmployees;
        SQLGetData(hstmt, 1, SQL_C_SLONG, &violators, 0, NULL);
        SQLGetData(hstmt, 2, SQL_C_SLONG, &totalViolations, 0, NULL);
        SQLGetData(hstmt, 3, SQL_C_SLONG, &totalEvents, 0, NULL);
        SQLGetData(hstmt, 4, SQL_C_SLONG, &totalEmployees, 0, NULL);

        cout << "\n[СТАТИСТИКА]:" << endl;
        cout << "   Всего сотрудников: " << totalEmployees << endl;
        cout << "   Всего событий: " << totalEvents << endl;
        cout << "   Всего нарушений: " << totalViolations << endl;
        cout << "   Нарушителей: " << violators << endl;
        if (totalEvents > 0) {
            double percent = (double)totalViolations * 100.0 / totalEvents;
            cout << "   Процент нарушений от событий: " << percent << "%" << endl;
        }
    }

    SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
}

// ГЛАВНОЕ МЕНЮ
int main() {
    SetConsoleOutputCP(1251);
    SetConsoleCP(1251);

    cout << "================================================================================" << endl;
    cout << "     КОНТРОЛЬНО-ПРОПУСКНАЯ СИСТЕМА (C++)" << endl;
    cout << "     Учет рабочего времени на основе RFID-карт" << endl;
    cout << "================================================================================" << endl;
    cout << endl;

    SQLHDBC hdbc = ConnectToDatabase();
    if (!hdbc) {
        cout << "[ОШИБКА] Не удалось подключиться к базе данных!" << endl;
        cout << "Проверьте строку подключения в коде." << endl;
        cout << "Нажмите Enter для выхода...";
        cin.get();
        return 1;
    }

    cout << "[OK] Подключение к базе данных установлено!" << endl;

    bool exit = false;
    while (!exit) {
        cout << "\n================================================================================" << endl;
        cout << "ГЛАВНОЕ МЕНЮ:" << endl;
        cout << "================================================================================" << endl;
        cout << "1. Регистрация события входа/выхода" << endl;
        cout << "2. Вывод статистики прихода и ухода" << endl;
        cout << "3. Вывод нарушителей (группировка по датам)" << endl;
        cout << "4. Вывод нарушителей за месяц/квартал/год" << endl;
        cout << "5. ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ (1000 вставок)" << endl;
        cout << "6. Полная аналитика нарушений" << endl;
        cout << "0. Выход" << endl;
        cout << "\nВыберите пункт: ";

        int choice;
        cin >> choice;
        cin.ignore();

        switch (choice) {
        case 1: {
            int empId, eventType;
            cout << "Введите ID сотрудника: ";
            cin >> empId;
            cout << "Тип события (1-Вход, 2-Выход): ";
            cin >> eventType;
            if (RegisterEvent(hdbc, empId, eventType))
                cout << "\n[OK] Событие зарегистрировано!" << endl;
            else
                cout << "\n[ОШИБКА] Не удалось зарегистрировать событие" << endl;
            break;
        }
        case 2: ShowStatistics(hdbc); break;
        case 3: ShowViolatorsByDate(hdbc); break;
        case 4: ShowViolatorsByPeriod(hdbc); break;
        case 5: PerformanceTest(hdbc); break;
        case 6: FullAnalytics(hdbc); break;
        case 0: exit = true; break;
        default: cout << "Неверный выбор!" << endl; break;
        }
    }

    SQLDisconnect(hdbc);
    SQLFreeHandle(SQL_HANDLE_DBC, hdbc);
    SQLFreeHandle(SQL_HANDLE_ENV, hdbc);

    cout << "\nПрограмма завершена. Нажмите Enter...";
    cin.get();
    cin.get();

    return 0;
}