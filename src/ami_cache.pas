unit ami_cache;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, syncobjs, Generics.Collections, Generics.Defaults, ami_types,
  DateUtils, ami_enums;

type
  TCachedEventItem = class;
  TCachedResponseItem = class;
  TCachedEventItemList = specialize TList<TCachedEventItem>;
  TCachedResponseItemList = specialize TList<TCachedResponseItem>;
  TStringList = specialize TList<string>;
  TEventDictionary = specialize TDictionary<string, TCachedEventItem>;
  TResponseDictionary = specialize TDictionary<string, TCachedResponseItem>;
  TEventCachePair = specialize TPair<string, TCachedEventItem>;
  TResponseCachePair = specialize TPair<string, TCachedResponseItem>;
  TEventCachePairList = specialize TList<TEventCachePair>;
  TResponseCachePairList = specialize TList<TResponseCachePair>;
  TEventCacheComparer = specialize TComparer<TEventCachePair>;
  TResponseCacheComparer = specialize TComparer<TResponseCachePair>;

{==============================================================================}
{=== TEventCacheLRUComparer =================================================}
{==============================================================================}

  TEventCacheLRUComparer = class(TEventCacheComparer)
  public
    function Compare(constref Left, Right: TEventCachePair): Integer; override;
  end;

{==============================================================================}
{=== TResponseCacheLRUComparer ==============================================}
{==============================================================================}

  TResponseCacheLRUComparer = class(TResponseCacheComparer)
  public
    function Compare(constref Left, Right: TResponseCachePair): Integer; override;
  end;

{==============================================================================}
{=== TAMIEventCache ==========================================================}
{==============================================================================}

  TAMIEventCache = class
  private
    FCache: TEventDictionary;
    FLock: TCriticalSection;
    FHitCount: Integer;
    FMissCount: Integer;
    FMaxSize: Integer;
    procedure CheckSize;
  public
    constructor Create(AMaxSize: Integer = 1000);
    destructor Destroy; override;
    function GetEventType(const AEventName: String): TAMIEventType;
    procedure PutEventType(const AEventName: String; AEventType: TAMIEventType);
    procedure Clear;
    procedure CleanupOldEntries(AMaxAgeMinutes: Integer);
    function GetHitRate: Double;
    function GetSize: Integer;
    property HitCount: Integer read FHitCount;
    property MissCount: Integer read FMissCount;
  end;

{==============================================================================}
{=== TAMIResponseCache =======================================================}
{==============================================================================}

  TAMIResponseCache = class
  private
    FCache: TResponseDictionary;
    FLock: TCriticalSection;
    FTTL: Integer;
    FMaxSize: Integer;
    procedure CheckSize;
  public
    constructor Create(ATTL: Integer = 300; AMaxSize: Integer = 500);
    destructor Destroy; override;
    procedure PutResponse(const AKey: String; AResponse: TAMIResponse);
    function GetResponse(const AKey: String): TAMIResponse;
    procedure RemoveResponse(const AKey: String);
    procedure CleanupExpired;
    procedure Clear;
    function GetSize: Integer;
    property TTL: Integer read FTTL write FTTL;
  end;

{==============================================================================}
{=== TCachedEventItem ========================================================}
{==============================================================================}

  TCachedEventItem = class
  public
    EventType: TAMIEventType;
    Timestamp: TDateTime;
    LastAccess: TDateTime;
    constructor Create(AEventType: TAMIEventType);
  end;

{==============================================================================}
{=== TCachedResponseItem =====================================================}
{==============================================================================}

  TCachedResponseItem = class
  public
    Response: TAMIResponse;
    Timestamp: TDateTime;
    LastAccess: TDateTime;
    constructor Create(AResponse: TAMIResponse);
    destructor Destroy; override;
  end;

implementation

uses
  Math;

{==============================================================================}
{=== TCachedEventItem ========================================================}
{==============================================================================}

constructor TCachedEventItem.Create(AEventType: TAMIEventType);
begin
  EventType := AEventType;
  Timestamp := Now;
  LastAccess := Now;
end;

{==============================================================================}
{=== TCachedResponseItem =====================================================}
{==============================================================================}

constructor TCachedResponseItem.Create(AResponse: TAMIResponse);
begin
  Response := AResponse;
  Timestamp := Now;
  LastAccess := Now;
end;

destructor TCachedResponseItem.Destroy;
begin
  FreeAndNil(Response);
  inherited Destroy;
end;

{==============================================================================}
{=== TEventCacheLRUComparer =================================================}
{==============================================================================}

function TEventCacheLRUComparer.Compare(constref Left, Right: TEventCachePair): Integer;
begin
  if Left.Value.LastAccess < Right.Value.LastAccess then
    Result := -1
  else if Left.Value.LastAccess > Right.Value.LastAccess then
    Result := 1
  else
    Result := 0;
end;

{==============================================================================}
{=== TResponseCacheLRUComparer ==============================================}
{==============================================================================}

function TResponseCacheLRUComparer.Compare(constref Left, Right: TResponseCachePair): Integer;
begin
  if Left.Value.LastAccess < Right.Value.LastAccess then
    Result := -1
  else if Left.Value.LastAccess > Right.Value.LastAccess then
    Result := 1
  else
    Result := 0;
end;

{==============================================================================}
{=== TAMIEventCache ==========================================================}
{==============================================================================}

constructor TAMIEventCache.Create(AMaxSize: Integer);
begin
  FCache := TEventDictionary.Create;
  FLock := TCriticalSection.Create;
  FMaxSize := AMaxSize;
  FHitCount := 0;
  FMissCount := 0;
end;

destructor TAMIEventCache.Destroy;
begin
  Clear;
  FreeAndNil(FCache);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TAMIEventCache.CheckSize;
var
  KeyValuePairs: TEventCachePairList;
  PairEnum: TEventDictionary.TPairEnumerator;
  Pair: TEventCachePair;
  i, CountToRemove: Integer;
  Key: string;
  Comparer: TEventCacheLRUComparer;
begin
  if FCache.Count <= FMaxSize then
    Exit;

  KeyValuePairs := TEventCachePairList.Create;
  Comparer := TEventCacheLRUComparer.Create;
  try
    PairEnum := FCache.GetEnumerator;
    try
      while PairEnum.MoveNext do
        KeyValuePairs.Add(PairEnum.Current);
    finally
      PairEnum.Free;
    end;

    KeyValuePairs.Sort(Comparer);

    CountToRemove := FCache.Count - FMaxSize;
    for i := 0 to CountToRemove - 1 do
    begin
      if i < KeyValuePairs.Count then
      begin
        Key := KeyValuePairs[i].Key;
        FCache[Key].Free;
        FCache.Remove(Key);
      end;
    end;
  finally
    Comparer.Free;
    KeyValuePairs.Free;
  end;
end;

function TAMIEventCache.GetEventType(const AEventName: String): TAMIEventType;
var
  UpperName: String;
  Item: TCachedEventItem;
begin
  FLock.Enter;
  try
    UpperName := UpperCase(AEventName);
    if FCache.TryGetValue(UpperName, Item) then
    begin
      Item.LastAccess := Now;
      Inc(FHitCount);
      Result := Item.EventType;
    end
    else
    begin
      Inc(FMissCount);
      Result := etUnknown;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventCache.PutEventType(const AEventName: String; AEventType: TAMIEventType);
var
  UpperName: String;
  Item: TCachedEventItem;
begin
  FLock.Enter;
  try
    CheckSize;

    UpperName := UpperCase(AEventName);

    if FCache.TryGetValue(UpperName, Item) then
    begin
      Item.Free;
      FCache.Remove(UpperName);
    end;

    Item := TCachedEventItem.Create(AEventType);
    FCache.Add(UpperName, Item);
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventCache.Clear;
var
  Item: TCachedEventItem;
begin
  FLock.Enter;
  try
    for Item in FCache.Values do
      Item.Free;
    FCache.Clear;
    FHitCount := 0;
    FMissCount := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TAMIEventCache.CleanupOldEntries(AMaxAgeMinutes: Integer);
var
  KeysToRemove: TStringList;
  PairEnum: TEventDictionary.TPairEnumerator;
  CutoffTime: TDateTime;
  Key: string;
  RemovedCount: Integer;
begin
  RemovedCount := 0;
  CutoffTime := Now - (AMaxAgeMinutes / 1440);

  KeysToRemove := TStringList.Create;
  try
    FLock.Enter;
    try
      PairEnum := FCache.GetEnumerator;
      try
        while PairEnum.MoveNext do
        begin
          if PairEnum.Current.Value.LastAccess < CutoffTime then
            KeysToRemove.Add(PairEnum.Current.Key);
        end;
      finally
        PairEnum.Free;
      end;

      for Key in KeysToRemove do
      begin
        FCache[Key].Free;
        FCache.Remove(Key);
        Inc(RemovedCount);
      end;
    finally
      FLock.Leave;
    end;
  finally
    KeysToRemove.Free;
  end;
end;

function TAMIEventCache.GetHitRate: Double;
begin
  FLock.Enter;
  try
    if (FHitCount + FMissCount) > 0 then
      Result := FHitCount / (FHitCount + FMissCount)
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TAMIEventCache.GetSize: Integer;
begin
  FLock.Enter;
  try
    Result := FCache.Count;
  finally
    FLock.Leave;
  end;
end;

{==============================================================================}
{=== TAMIResponseCache =======================================================}
{==============================================================================}

constructor TAMIResponseCache.Create(ATTL: Integer; AMaxSize: Integer);
begin
  FCache := TResponseDictionary.Create;
  FLock := TCriticalSection.Create;
  FTTL := ATTL;
  FMaxSize := AMaxSize;
end;

destructor TAMIResponseCache.Destroy;
begin
  Clear;
  FreeAndNil(FCache);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TAMIResponseCache.CheckSize;
var
  KeyValuePairs: TResponseCachePairList;
  PairEnum: TResponseDictionary.TPairEnumerator;
  i, CountToRemove: Integer;
  Key: string;
  Comparer: TResponseCacheLRUComparer;
begin
  if FCache.Count <= FMaxSize then
    Exit;

  KeyValuePairs := TResponseCachePairList.Create;
  Comparer := TResponseCacheLRUComparer.Create;
  try
    PairEnum := FCache.GetEnumerator;
    try
      while PairEnum.MoveNext do
        KeyValuePairs.Add(PairEnum.Current);
    finally
      PairEnum.Free;
    end;

    KeyValuePairs.Sort(Comparer);

    CountToRemove := FCache.Count - FMaxSize;
    for i := 0 to CountToRemove - 1 do
    begin
      if i < KeyValuePairs.Count then
      begin
        Key := KeyValuePairs[i].Key;
        FCache[Key].Free;
        FCache.Remove(Key);
      end;
    end;
  finally
    Comparer.Free;
    KeyValuePairs.Free;
  end;
end;

procedure TAMIResponseCache.PutResponse(const AKey: String; AResponse: TAMIResponse);
var
  Item: TCachedResponseItem;
  OldItem: TCachedResponseItem;
begin
  FLock.Enter;
  try
    CheckSize;

    if AResponse is TAMICommandResponse then
      Item := TCachedResponseItem.Create(TAMICommandResponse.Create)
    else
      Item := TCachedResponseItem.Create(TAMIResponse.Create);
    Item.Response.Assign(AResponse);
    Item.Timestamp := Now;
    Item.LastAccess := Now;

    if FCache.TryGetValue(AKey, OldItem) then
    begin
      OldItem.Free;
      FCache.Remove(AKey);
    end;

    FCache.Add(AKey, Item);
  finally
    FLock.Leave;
  end;
end;

function TAMIResponseCache.GetResponse(const AKey: String): TAMIResponse;
var
  Item: TCachedResponseItem;
begin
  Result := nil;
  FLock.Enter;
  try
    if FCache.TryGetValue(AKey, Item) then
    begin
      if SecondsBetween(Now, Item.Timestamp) <= FTTL then
      begin
        Item.LastAccess := Now;
        if Item.Response is TAMICommandResponse then
          Result := TAMICommandResponse.Create
        else
          Result := TAMIResponse.Create;
        Result.Assign(Item.Response);
      end
      else
      begin
        Item.Free;
        FCache.Remove(AKey);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAMIResponseCache.RemoveResponse(const AKey: String);
var
  Item: TCachedResponseItem;
begin
  FLock.Enter;
  try
    if FCache.TryGetValue(AKey, Item) then
    begin
      Item.Free;
      FCache.Remove(AKey);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TAMIResponseCache.CleanupExpired;
var
  KeysToRemove: TStringList;
  PairEnum: TResponseDictionary.TPairEnumerator;
  Key: string;
begin
  KeysToRemove := TStringList.Create;
  try
    FLock.Enter;
    try
      PairEnum := FCache.GetEnumerator;
      try
        while PairEnum.MoveNext do
        begin
          if SecondsBetween(Now, PairEnum.Current.Value.Timestamp) > FTTL then
            KeysToRemove.Add(PairEnum.Current.Key);
        end;
      finally
        PairEnum.Free;
      end;

      for Key in KeysToRemove do
      begin
        FCache[Key].Free;
        FCache.Remove(Key);
      end;
    finally
      FLock.Leave;
    end;
  finally
    KeysToRemove.Free;
  end;
end;

procedure TAMIResponseCache.Clear;
var
  Item: TCachedResponseItem;
begin
  FLock.Enter;
  try
    for Item in FCache.Values do
      Item.Free;
    FCache.Clear;
  finally
    FLock.Leave;
  end;
end;

function TAMIResponseCache.GetSize: Integer;
begin
  FLock.Enter;
  try
    Result := FCache.Count;
  finally
    FLock.Leave;
  end;
end;

end.
