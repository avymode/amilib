# AMILIB - Библиотека Asterisk AMI для Free Pascal

[![Build Status](https://github.com/avymode/amilib/actions/workflows/build.yml/badge.svg)](https://github.com/avymode/amilib/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Free Pascal](https://img.shields.io/badge/Free%20Pascal-3.2.2-green.svg)](https://www.freepascal.org/)

[English](README.md) | Русский

## Обзор

AMILIB - мощная, потокобезопасная библиотека Free Pascal для подключения к Asterisk PBX через Asterisk Manager Interface (AMI). Она предоставляет удобный объектно-ориентированный API для отправки действий, получения событий и управления подключениями.

## Возможности

- **Синхронные и асинхронные операции**: Отправляйте действия и получайте ответы синхронно или обрабатывайте их асинхронно с помощью колбэков
- **Потокобезопасный дизайн**: Разработано для многопоточных приложений с правильной синхронизацией
- **Событийная система**: Мощная система публикации/подписки с возможностью фильтрации
- **Поддержка TLS/SSL**: Безопасные подключения к Asterisk
- **Поддержка IPv6**: Подключение через IPv4 или IPv6
- **Автоматическое переподключение**: Автоматическое переподключение с экспоненциальной задержкой
- **Ограничение частоты**: Настраиваемое ограничение действий в секунду
- **Кэширование**: Встроенное кэширование часто запрашиваемых данных
- **Логирование**: Комплексная система логирования

## Требования

- Free Pascal Compiler 3.2.2+
- Lazarus IDE (опционально, для разработки GUI)
- Сетевая библиотека Synapse

## Установка

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/avymode/amilib.git
   ```

2. Добавьте директорию `src` в пути поиска вашего проекта

3. Добавьте необходимые модули в секцию uses:
   ```pascal
   uses ami_client, ami_types, ami_log;
   ```

## Быстрый старт

```pascal
program MyFirstApp;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, ami_client, ami_types, ami_log;

var
  Client: TAMIClient;
  Config: TAMIClientConfig;
  Response: TAMIResponse;
begin
  // Настройка клиента
  Config.Host := 'ASTERISK_HOST';
  Config.Port := 5038;
  Config.Username := 'AMI_USERNAME';
  Config.Password := 'AMI_PASSWORD';
  Config.AuthType := 'plain';

  // Инициализация логирования
  AmiLogInit('', True, llInfo);

  // Создание клиента
  Client := TAMIClient.Create(Config);
  try
    // Подключение
    if Client.Connect then
    begin
      WriteLn('Подключено к Asterisk!');

      // Отправка Ping
      Response := Client.Ping(5000);
      if Assigned(Response) and Response.IsSuccess then
        WriteLn('Ping успешен!')
      else
        WriteLn('Ping неудачен!');

      // Отключение
      Client.Disconnect;
    end
    else
      WriteLn('Ошибка подключения: ', Client.Transport.LastError);
  finally
    Client.Free;
    AmiLogShutdown;
  end;
end.
```

## Параметры конфигурации

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| Host | Имя хоста/IP Asterisk | - |
| Port | Порт AMI | 5038 |
| Username | Имя пользователя AMI | - |
| Password | Пароль AMI | - |
| AuthType | Тип аутентификации ('plain' или 'md5') | 'plain' |
| UseTLS | Включить TLS/SSL | False |
| UseIPv6 | Использовать IPv6 | False |
| ConnectionTimeout | Таймаут подключения (мс) | 10000 |
| ResponseTimeout | Таймаут ответа (мс) | 30000 |
| PingInterval | Интервал проверки (сек) | 30 |
| MaxReconnectAttempts | Макс. попыток переподключения | 3 |
| MaxActionsPerSecond | Ограничение частоты | 10 |

## Примеры

Директория `examples` содержит демонстрационные приложения:

- **Basic**: Простой пример подключения и Ping
- **QueueMonitor**: Мониторинг очередей в реальном времени
- **ChannelMonitor**: Мониторинг состояния каналов
- **Dashboard**: Полноценное приложение дашборда
- **CompleteApp**: Шаблон полноценного приложения

## Документация

- [Быстрый старт](docs/Quick_Start.md) - Руководство по началу работы
- [Справка по API](docs/Complete_API_Reference.md) - Полная документация API
- [Архитектура](docs/Architecture.md) - Архитектура библиотеки

## Тестирование

Запуск тестового набора:
```bash
cd tests
lazbuild ami_test_suite.lpi
./ami_test_suite.exe
```

## Вклад в проект

Вклад приветствуется! Пожалуйста, прочитайте наши [Руководство для контрибьюторов](CONTRIBUTING.md) перед отправкой pull requests.

## Лицензия

Проект распространяется под лицензией MIT - см. файл [LICENSE](LICENSE).

## Поддержка

- Откройте issue на GitHub
- Изучите документацию в папке `docs`
- Просмотрите примеры в папке `examples`

## Благодарности

- Команде Asterisk за протокол AMI
- Сообществу Free Pascal
- Авторам сетевой библиотеки Synapse
