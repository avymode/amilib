unit test_ami_cache;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  ami_cache, ami_types, ami_enums;

type
  { TTestAMICache }

  TTestAMICache = class(TTestCase)
  private
    FEventCache: TAMIEventCache;
    FResponseCache: TAMIResponseCache;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEventCachePutGet;
    procedure TestEventCacheLRU;
    procedure TestEventCacheClear;
    procedure TestEventCacheHitMiss;
    procedure TestResponseCachePutGet;
    procedure TestResponseCacheTTL;
    procedure TestResponseCacheClear;
    procedure TestResponseCacheCleanup;
  end;

implementation

{ TTestAMICache }

procedure TTestAMICache.SetUp;
begin
  inherited SetUp;
  FEventCache := TAMIEventCache.Create(10);
  FResponseCache := TAMIResponseCache.Create(60, 5);
end;

procedure TTestAMICache.TearDown;
begin
  FreeAndNil(FEventCache);
  FreeAndNil(FResponseCache);
  inherited TearDown;
end;

procedure TTestAMICache.TestEventCachePutGet;
var
  EventType: TAMIEventType;
begin
  FEventCache.PutEventType('TestEvent', etNewchannel);
  EventType := FEventCache.GetEventType('TestEvent');
  AssertEquals('Event type should match', Ord(etNewchannel), Ord(EventType));
end;

procedure TTestAMICache.TestEventCacheLRU;
var
  i: Integer;
  EventType: TAMIEventType;
begin
  for i := 1 to 15 do
    FEventCache.PutEventType('Event' + IntToStr(i), etNewchannel);

  AssertEquals('Cache should respect max size', 10, FEventCache.GetSize);

  EventType := FEventCache.GetEventType('Event1');
  AssertEquals('Oldest event should be evicted', Ord(etUnknown), Ord(EventType));
end;

procedure TTestAMICache.TestEventCacheClear;
begin
  FEventCache.PutEventType('TestEvent1', etNewchannel);
  FEventCache.PutEventType('TestEvent2', etHangup);
  AssertEquals('Cache should have 2 items', 2, FEventCache.GetSize);

  FEventCache.Clear;
  AssertEquals('Cache should be empty after clear', 0, FEventCache.GetSize);
end;

procedure TTestAMICache.TestEventCacheHitMiss;
begin
  FEventCache.PutEventType('HitEvent', etNewchannel);

  FEventCache.GetEventType('HitEvent');
  FEventCache.GetEventType('MissEvent');

  AssertEquals('Hit count should be 1', 1, FEventCache.HitCount);
  AssertEquals('Miss count should be 1', 1, FEventCache.MissCount);
  AssertEquals('Hit rate should be 50%', 0.5, FEventCache.GetHitRate);
end;

procedure TTestAMICache.TestResponseCachePutGet;
var
  Response: TAMIResponse;
  CachedResponse: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    Response.AddField('Response', 'Success');
    Response.AddField('Message', 'Test message');

    FResponseCache.PutResponse('test_key', Response);
    CachedResponse := FResponseCache.GetResponse('test_key');

    AssertNotNull('Cached response should not be nil', CachedResponse);
    AssertEquals('Response should match', 'Success', CachedResponse.GetField('Response'));
  finally
    Response.Free;
    FreeAndNil(CachedResponse);
  end;
end;

procedure TTestAMICache.TestResponseCacheTTL;
var
  Response: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    Response.AddField('Response', 'Success');

    FResponseCache.PutResponse('ttl_test', Response);
    Sleep(100);

    FreeAndNil(Response);
    Response := FResponseCache.GetResponse('ttl_test');

    AssertNull('Expired response should return nil', Response);
  finally
    Response.Free;
  end;
end;

procedure TTestAMICache.TestResponseCacheClear;
var
  Response: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    Response.AddField('Response', 'Success');

    FResponseCache.PutResponse('key1', Response);
    FResponseCache.PutResponse('key2', Response);
    AssertEquals('Cache should have 2 items', 2, FResponseCache.GetSize);

    FResponseCache.Clear;
    AssertEquals('Cache should be empty', 0, FResponseCache.GetSize);
  finally
    Response.Free;
  end;
end;

procedure TTestAMICache.TestResponseCacheCleanup;
var
  Response: TAMIResponse;
begin
  Response := TAMIResponse.Create;
  try
    Response.AddField('Response', 'Success');

    FResponseCache.PutResponse('key1', Response);
    Sleep(100);

    FResponseCache.CleanupExpired;
    AssertEquals('Expired key should be removed', 0, FResponseCache.GetSize);
  finally
    Response.Free;
  end;
end;

initialization
  RegisterTest(TTestAMICache);
end.
