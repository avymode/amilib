unit ami_exceptions;
{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { Базовое исключение AMI }
  EAMIException = class(Exception)
  private
    FErrorCode: Integer;
  public
    constructor Create(const AMsg: string; AErrorCode: Integer = 0); overload;
    property ErrorCode: Integer read FErrorCode;
  end;

  { Исключения соединения }
  EAMIConnectionException = class(EAMIException);
  EAMITimeoutException = class(EAMIConnectionException);
  EAMITransportException = class(EAMIConnectionException);

  { Исключения аутентификации }
  EAMIAuthenticationException = class(EAMIException);
  EAMIAuthFailedException = class(EAMIAuthenticationException);
  EAMIAuthNotSupportedException = class(EAMIAuthenticationException);

  { Исключения протокола }
  EAMIProtocolException = class(EAMIException);
  EAMIInvalidMessageException = class(EAMIProtocolException);
  EAMIUnsupportedActionException = class(EAMIProtocolException);

  { Исключения операций }
  EAMIInvalidOperation = class(EAMIException);
  EAMIInvalidParameterException = class(EAMIInvalidOperation);
  EAMIActionFailedException = class(EAMIInvalidOperation);

  { Исключения потоков }
  EAMIThreadException = class(EAMIException);
  EAMIThreadTerminatedException = class(EAMIThreadException);

  { Исключения кэширования }
  EAMICacheException = class(EAMIException);
  EAMICacheFullException = class(EAMICacheException);

  { Исключения валидации }
  EAMIValidationException = class(EAMIException);

  { Исключения плагинов }
  EAMIPluginException = class(EAMIException);
  EAMIPluginLoadException = class(EAMIPluginException);
  EAMIPluginExecutionException = class(EAMIPluginException);

implementation

{ EAMIException }

constructor EAMIException.Create(const AMsg: string; AErrorCode: Integer);
begin
  inherited Create(AMsg);
  FErrorCode := AErrorCode;
end;

end.
