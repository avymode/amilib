unit ami_actions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ami_types, ami_utils, syncobjs, ami_enums;

type
  { ============================================================================
    CORE ACTIONS
    ============================================================================ }

  TAMIOriginateAction = class(TAMIAction)
  public
    constructor Create;
    procedure SetParams(const AParams: TOriginateParams);
  end;

  TAMIHangupAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string; ACause: integer = 16);
  end;

  TAMICommandAction = class(TAMIAction)
  public
    constructor Create(const ACommand: string);
  end;

  { ============================================================================
    QUEUE ACTIONS
    ============================================================================ }

  TAMIQueueAddAction = class(TAMIAction)
  public
    constructor Create(const AQueueName, AMember: string;
      APenalty: integer = 0; APaused: boolean = False);
  end;

  TAMIQueueRemoveAction = class(TAMIAction)
  public
    constructor Create(const AQueueName, AMember: string);
  end;

  TAMIQueueStatusAction = class(TAMIAction)
  public
    constructor Create(const AQueueName: string = ''; const AMember: string = '');
  end;

  TAMIQueuePauseAction = class(TAMIAction)
  public
    constructor Create(const AQueueName, AMember: string; APaused: boolean = True);
  end;

  TAMIQueuePenaltyAction = class(TAMIAction)
  public
    constructor Create(const AInterface: string; APenalty: integer;
      const AQueue: string = '');
  end;

  TAMIQueueReloadAction = class(TAMIAction)
  public
    constructor Create(const AQueueName: string = '');
  end;

  TAMIQueueResetAction = class(TAMIAction)
  public
    constructor Create(const AQueueName: string);
  end;

  TAMIQueueRuleAction = class(TAMIAction)
  public
    constructor Create(const ARuleName: string);
  end;

  TAMIQueueSummaryAction = class(TAMIAction)
  public
    constructor Create(const AQueueName: string = '');
  end;

  { ============================================================================
    CHANNEL ACTIONS
    ============================================================================ }

  TAMIRedirectAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AContext, AExtension: string;
      APriority: integer = 1; const AExtraChannel: string = '');
  end;

  TAMIAtxferAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AContext, AExtension: string;
      APriority: integer = 1);
  end;

  TAMIBridgeAction = class(TAMIAction)
  public
    constructor Create(const AChannel1, AChannel2: string; ATone: boolean = True);
  end;

  TAMIParkAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AChannel2: string;
      ATimeout: integer = 0; const AParkinglot: string = '');
  end;

  TAMIPlayDTMFAction = class(TAMIAction)
  public
    constructor Create(const AChannel, ADigit: string; ADuration: integer = 250);
  end;

  TAMISendTextAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AMessage: string);
  end;

  TAMISetVarAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AVariable, AValue: string);
  end;

  TAMIGetVarAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AVariable: string);
  end;


  { ============================================================================
    ASTDB ACTIONS
    ============================================================================ }

  TAMIDBGetAction = class(TAMIAction)
  public
    constructor Create(const AFamily, AKey: string);
  end;

  TAMIDBPutAction = class(TAMIAction)
  public
    constructor Create(const AFamily, AKey, AVal: string);
  end;

  TAMIDBDelAction = class(TAMIAction)
  public
    constructor Create(const AFamily, AKey: string);
  end;

  TAMIDBDelTreeAction = class(TAMIAction)
  public
    constructor Create(const AFamily, AKey: string);
  end;

  TAMIDBGetTreeAction = class(TAMIAction)
  public
    constructor Create(const AFamily, AKey: string);
  end;

  { ============================================================================
    CONFERENCING ACTIONS
    ============================================================================ }

  TAMIConfbridgeKickAction = class(TAMIAction)
  public
    constructor Create(const AConference, AChannel: string);
  end;

  TAMIConfbridgeListAction = class(TAMIAction)
  public
    constructor Create(const AConference: string = '');
  end;

  TAMIConfbridgeListRoomsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIConfbridgeLockAction = class(TAMIAction)
  public
    constructor Create(const AConference: string);
  end;

  TAMIConfbridgeUnlockAction = class(TAMIAction)
  public
    constructor Create(const AConference: string);
  end;

  TAMIConfbridgeMuteAction = class(TAMIAction)
  public
    constructor Create(const AConference, AChannel: string);
  end;

  TAMIConfbridgeUnmuteAction = class(TAMIAction)
  public
    constructor Create(const AConference, AChannel: string);
  end;

  TAMIConfbridgeStartRecordAction = class(TAMIAction)
  public
    constructor Create(const AConference: string; const ARecordFile: string = '');
  end;

  TAMIConfbridgeStopRecordAction = class(TAMIAction)
  public
    constructor Create(const AConference: string);
  end;

  TAMIConfbridgeSetSingleVideoSrcAction = class(TAMIAction)
  public
    constructor Create(const AConference, AChannel: string);
  end;

  { ============================================================================
    MEETME ACTIONS
    ============================================================================ }

  TAMIMeetmeListAction = class(TAMIAction)
  public
    constructor Create(const AConference: string = '');
  end;

  TAMIMeetmeListRoomsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIMeetmeMuteAction = class(TAMIAction)
  public
    constructor Create(const AMeetme, AUsernum: string);
  end;

  TAMIMeetmeUnmuteAction = class(TAMIAction)
  public
    constructor Create(const AMeetme, AUsernum: string);
  end;

  { ============================================================================
    PJSIP ACTIONS (Asterisk 13+)
    ============================================================================ }

  TAMIPJSIPNotifyAction = class(TAMIAction)
  public
    constructor Create(const AEndpoint, AVariable: string);
  end;

  TAMIPJSIPQualifyAction = class(TAMIAction)
  public
    constructor Create(const AEndpoint: string);
  end;

  TAMIPJSIPShowEndpointsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowEndpointAction = class(TAMIAction)
  public
    constructor Create(const AEndpoint: string);
  end;

  TAMIPJSIPShowRegistrationInboundContactStatusesAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowRegistrationsInboundAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowRegistrationsOutboundAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowResourceListsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowSubscriptionsInboundAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIPJSIPShowSubscriptionsOutboundAction = class(TAMIAction)
  public
    constructor Create;
  end;

  { ============================================================================
    SIP ACTIONS (Legacy - pre Asterisk 13)
    ============================================================================ }

  TAMISIPnotifyAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AVariable: string);
  end;

  TAMISIPpeersAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMISIPshowpeerAction = class(TAMIAction)
  public
    constructor Create(const APeer: string);
  end;

  TAMISIPshowregistryAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMISIPqualifypeerAction = class(TAMIAction)
  public
    constructor Create(const APeer: string);
  end;

  { ============================================================================
    VOICEMAIL ACTIONS
    ============================================================================ }

  TAMIVoicemailUsersListAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIMailboxStatusAction = class(TAMIAction)
  public
    constructor Create(const AMailbox: string);
  end;

  TAMIMailboxCountAction = class(TAMIAction)
  public
    constructor Create(const AMailbox: string);
  end;

  { ============================================================================
    SYSTEM ACTIONS
    ============================================================================ }

  TAMIPingAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIEventsAction = class(TAMIAction)
  public
    constructor Create(const AEventMask: string = 'on');
  end;

  TAMILogoffAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIChallengeAction = class(TAMIAction)
  public
    constructor Create(const AAuthType: string);
  end;

  TAMILoginAction = class(TAMIAction)
  public
    constructor Create(const AUsername, APassword: string;
      const AAuthType: string = 'plain');
  end;

  TAMICoreShowChannelsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMICoreStatusAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMICoreSettingsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIReloadAction = class(TAMIAction)
  public
    constructor Create(const AModule: string = '');
  end;

  TAMIModuleLoadAction = class(TAMIAction)
  public
    constructor Create(const AModule: string; const ALoadType: string = 'load');
  end;

  TAMIModuleCheckAction = class(TAMIAction)
  public
    constructor Create(const AModule: string);
  end;

  TAMIExtensionStateListAction = class(TAMIAction)
  public
    constructor Create;
  end;

  TAMIExtensionStateAction = class(TAMIAction)
  public
    constructor Create(const AExtension: String; AContext: string = 'from-internal');
  end;

  { ============================================================================
    MONITORING ACTIONS
    ============================================================================ }

  TAMIMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AFile: string; const AFormat: string = 'wav';
      AMix: boolean = False);
  end;

  TAMIStopMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string);
  end;

  TAMIPauseMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string);
  end;

  TAMIUnpauseMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string);
  end;

  TAMIChangeMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AFile: string);
  end;

  TAMIMixMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AFile: string; const AOptions: string = '');
  end;

  TAMIMixMonitorMuteAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string; const ADirection: string = 'both';
      AState: boolean = True);
  end;

  TAMIStopMixMonitorAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string; const AMixMonitorID: string = '');
  end;

  { ============================================================================
    CALL DETAIL RECORDS
    ============================================================================ }

  TAMIGetConfigAction = class(TAMIAction)
  public
    constructor Create(const AFilename: string; const ACategory: string = '');
  end;

  TAMIGetConfigJSONAction = class(TAMIAction)
  public
    constructor Create(const AFilename: string);
  end;

  TAMIUpdateConfigAction = class(TAMIAction)
  public
    constructor Create(const ASrcFilename, ADstFilename: string);
  end;

  TAMICreateConfigAction = class(TAMIAction)
  public
    constructor Create(const AFilename: string);
  end;

  TAMIListCategoriesAction = class(TAMIAction)
  public
    constructor Create(const AFilename: string);
  end;

  { ============================================================================
    BRIDGE ACTIONS
    ============================================================================ }

  TAMIBridgeInfoAction = class(TAMIAction)
  public
    constructor Create(const ABridgeUniqueid: string);
  end;

  TAMIBridgeListAction = class(TAMIAction)
  public
    constructor Create(const ABridgeType: string = '');
  end;

  TAMIBridgeDestroyAction = class(TAMIAction)
  public
    constructor Create(const ABridgeUniqueid: string);
  end;

  TAMIBridgeKickAction = class(TAMIAction)
  public
    constructor Create(const ABridgeUniqueid, AChannel: string);
  end;

  { ============================================================================
    AGENT ACTIONS
    ============================================================================ }

  TAMIAgentLogoffAction = class(TAMIAction)
  public
    constructor Create(const AAgent: string; ASoft: boolean = False);
  end;

  TAMIAgentsAction = class(TAMIAction)
  public
    constructor Create;
  end;

  { ============================================================================
    MISC ACTIONS
    ============================================================================ }

  TAMIUserEventAction = class(TAMIAction)
  public
    constructor Create(const AUserEvent: string);
    procedure AddHeader(const AKey, AValue: string);
  end;

  TAMIWaitEventAction = class(TAMIAction)
  public
    constructor Create(ATimeout: integer = 30000);
  end;

  TAMIShowDialPlanAction = class(TAMIAction)
  public
    constructor Create(const AContext: string = ''; const AExtension: string = '');
  end;

  TAMIDataGetAction = class(TAMIAction)
  public
    constructor Create(const APath: string; const ASearch: string = '';
      const AFilter: string = '');
  end;

  TAMIFilterAction = class(TAMIAction)
  public
    constructor Create(const AOperation: string; const AFilter: string);
  end;

  TAMIBlindTransferAction = class(TAMIAction)
  public
    constructor Create(const AChannel, AContext, AExten: string);
  end;

  TAMICancelAtxferAction = class(TAMIAction)
  public
    constructor Create(const AChannel: string);
  end;


  { ============================================================================
    PENDING ACTION (Internal use)
    ============================================================================ }

  TPendingAction = class(TObject)
  private
    FAction: TAMIAction;
    FResponse: TAMIResponse;
    FActionID: string;
    FCreateTime: TDateTime;
    FOnResponse: TAMIResponseEvent;
    FWaitEvent: TSimpleEvent;
  public
    constructor Create(AAction: TAMIAction);
    destructor Destroy; override;
    procedure SignalDone;
    function Wait(ATimeout: cardinal): TWaitResult;
    property ActionID: string read FActionID;
    property Action: TAMIAction read FAction;
    property Response: TAMIResponse read FResponse write FResponse;
    property CreateTime: TDateTime read FCreateTime;
    property OnResponse: TAMIResponseEvent read FOnResponse write FOnResponse;
  end;

implementation

uses
  StrUtils;

{ TAMIOriginateAction }

constructor TAMIOriginateAction.Create;
begin
  inherited Create('Originate');
end;

procedure TAMIOriginateAction.SetParams(const AParams: TOriginateParams);
var
  i: integer;
begin
  if AParams.Channel <> '' then AddField('Channel', AParams.Channel);
  if AParams.Context <> '' then AddField('Context', AParams.Context);
  if AParams.Extension <> '' then AddField('Exten', AParams.Extension);
  if AParams.Priority <> '' then AddField('Priority', AParams.Priority);
  if AParams.Application <> '' then AddField('Application', AParams.Application);
  if AParams.Data <> '' then AddField('Data', AParams.Data);
  if AParams.Timeout > 0 then AddField('Timeout', IntToStr(AParams.Timeout));
  if AParams.CallerID <> '' then AddField('CallerID', AParams.CallerID);
  if AParams.Account <> '' then AddField('Account', AParams.Account);
  if AParams.Async then AddField('Async', 'true');
  if AParams.ActionID <> '' then AddField('ActionID', AParams.ActionID);
  if AParams.EarlyMedia then AddField('EarlyMedia', 'true');
  if AParams.Codecs <> '' then AddField('Codecs', AParams.Codecs);
  if AParams.ChannelId <> '' then AddField('ChannelId', AParams.ChannelId);

  if Assigned(AParams.Variables) then
  begin
    for i := 0 to AParams.Variables.Count - 1 do
      AddField('Variable', AParams.Variables[i]);
  end;
end;

{ TAMIHangupAction }

constructor TAMIHangupAction.Create(const AChannel: string; ACause: integer);
begin
  inherited Create('Hangup');
  AddField('Channel', AChannel);
  if ACause > 0 then
    AddField('Cause', IntToStr(ACause));
end;

{ TAMICommandAction }

constructor TAMICommandAction.Create(const ACommand: string);
begin
  inherited Create('Command');
  AddField('Command', ACommand);
end;

{ TAMIQueueAddAction }

constructor TAMIQueueAddAction.Create(const AQueueName, AMember: string;
  APenalty: integer; APaused: boolean);
begin
  inherited Create('QueueAdd');
  AddField('Queue', AQueueName);
  AddField('Interface', AMember);
  if APenalty > 0 then
    AddField('Penalty', IntToStr(APenalty));
  if APaused then
    AddField('Paused', 'true');
end;

{ TAMIQueueRemoveAction }

constructor TAMIQueueRemoveAction.Create(const AQueueName, AMember: string);
begin
  inherited Create('QueueRemove');
  AddField('Queue', AQueueName);
  AddField('Interface', AMember);
end;

{ TAMIQueueStatusAction }

constructor TAMIQueueStatusAction.Create(const AQueueName: string;
  const AMember: string);
begin
  inherited Create('QueueStatus');
  if AQueueName <> '' then
    AddField('Queue', AQueueName);
  if AMember <> '' then
    AddField('Member', AMember);
end;

{ TAMIQueuePauseAction }

constructor TAMIQueuePauseAction.Create(const AQueueName, AMember: string;
  APaused: boolean);
begin
  inherited Create('QueuePause');
  AddField('Interface', AMember);
  if AQueueName <> '' then
    AddField('Queue', AQueueName);
  AddField('Paused', IfThen(APaused, 'true', 'false'));
end;

{ TAMIQueuePenaltyAction }

constructor TAMIQueuePenaltyAction.Create(const AInterface: string;
  APenalty: integer; const AQueue: string);
begin
  inherited Create('QueuePenalty');
  AddField('Interface', AInterface);
  AddField('Penalty', IntToStr(APenalty));
  if AQueue <> '' then
    AddField('Queue', AQueue);
end;

{ TAMIQueueReloadAction }

constructor TAMIQueueReloadAction.Create(const AQueueName: string);
begin
  inherited Create('QueueReload');
  if AQueueName <> '' then
    AddField('Queue', AQueueName);
end;

{ TAMIQueueResetAction }

constructor TAMIQueueResetAction.Create(const AQueueName: string);
begin
  inherited Create('QueueReset');
  AddField('Queue', AQueueName);
end;

{ TAMIQueueRuleAction }

constructor TAMIQueueRuleAction.Create(const ARuleName: string);
begin
  inherited Create('QueueRule');
  AddField('Rule', ARuleName);
end;

{ TAMIQueueSummaryAction }

constructor TAMIQueueSummaryAction.Create(const AQueueName: string);
begin
  inherited Create('QueueSummary');
  if AQueueName <> '' then
    AddField('Queue', AQueueName);
end;

{ TAMIRedirectAction }

constructor TAMIRedirectAction.Create(const AChannel, AContext, AExtension: string;
  APriority: integer; const AExtraChannel: string);
begin
  inherited Create('Redirect');
  AddField('Channel', AChannel);
  AddField('Context', AContext);
  AddField('Exten', AExtension);
  AddField('Priority', IntToStr(APriority));
  if AExtraChannel <> '' then
    AddField('ExtraChannel', AExtraChannel);
end;

{ TAMIAtxferAction }

constructor TAMIAtxferAction.Create(const AChannel, AContext, AExtension: string;
  APriority: integer);
begin
  inherited Create('Atxfer');
  AddField('Channel', AChannel);
  AddField('Context', AContext);
  AddField('Exten', AExtension);
  AddField('Priority', IntToStr(APriority));
end;

{ TAMIBridgeAction }

constructor TAMIBridgeAction.Create(const AChannel1, AChannel2: string; ATone: boolean);
begin
  inherited Create('Bridge');
  AddField('Channel1', AChannel1);
  AddField('Channel2', AChannel2);
  AddField('Tone', IfThen(ATone, 'yes', 'no'));
end;

{ TAMIParkAction }

constructor TAMIParkAction.Create(const AChannel, AChannel2: string;
  ATimeout: integer; const AParkinglot: string);
begin
  inherited Create('Park');
  AddField('Channel', AChannel);
  AddField('Channel2', AChannel2);
  if ATimeout > 0 then
    AddField('Timeout', IntToStr(ATimeout));
  if AParkinglot <> '' then
    AddField('Parkinglot', AParkinglot);
end;

{ TAMIPlayDTMFAction }

constructor TAMIPlayDTMFAction.Create(const AChannel, ADigit: string;
  ADuration: integer);
begin
  inherited Create('PlayDTMF');
  AddField('Channel', AChannel);
  AddField('Digit', ADigit);
  if ADuration > 0 then
    AddField('Duration', IntToStr(ADuration));
end;

{ TAMISendTextAction }

constructor TAMISendTextAction.Create(const AChannel, AMessage: string);
begin
  inherited Create('SendText');
  AddField('Channel', AChannel);
  AddField('Message', AMessage);
end;

{ TAMISetVarAction }

constructor TAMISetVarAction.Create(const AChannel, AVariable, AValue: string);
begin
  inherited Create('Setvar');
  if AChannel <> '' then
    AddField('Channel', AChannel);
  AddField('Variable', AVariable);
  AddField('Value', AValue);
end;

{ TAMIGetVarAction }

constructor TAMIGetVarAction.Create(const AChannel, AVariable: string);
begin
  inherited Create('Getvar');
  if AChannel <> '' then
    AddField('Channel', AChannel);
  AddField('Variable', AVariable);
end;

{ TAMIConfbridgeKickAction }

constructor TAMIConfbridgeKickAction.Create(const AConference, AChannel: string);
begin
  inherited Create('ConfbridgeKick');
  AddField('Conference', AConference);
  AddField('Channel', AChannel);
end;

{ TAMIConfbridgeListAction }

constructor TAMIConfbridgeListAction.Create(const AConference: string);
begin
  inherited Create('ConfbridgeList');
  if AConference <> '' then
    AddField('Conference', AConference);
end;

{ TAMIConfbridgeListRoomsAction }

constructor TAMIConfbridgeListRoomsAction.Create;
begin
  inherited Create('ConfbridgeListRooms');
end;

{ TAMIConfbridgeLockAction }

constructor TAMIConfbridgeLockAction.Create(const AConference: string);
begin
  inherited Create('ConfbridgeLock');
  AddField('Conference', AConference);
end;

{ TAMIConfbridgeUnlockAction }

constructor TAMIConfbridgeUnlockAction.Create(const AConference: string);
begin
  inherited Create('ConfbridgeUnlock');
  AddField('Conference', AConference);
end;

{ TAMIConfbridgeMuteAction }

constructor TAMIConfbridgeMuteAction.Create(const AConference, AChannel: string);
begin
  inherited Create('ConfbridgeMute');
  AddField('Conference', AConference);
  AddField('Channel', AChannel);
end;

{ TAMIConfbridgeUnmuteAction }

constructor TAMIConfbridgeUnmuteAction.Create(const AConference, AChannel: string);
begin
  inherited Create('ConfbridgeUnmute');
  AddField('Conference', AConference);
  AddField('Channel', AChannel);
end;

{ TAMIConfbridgeStartRecordAction }

constructor TAMIConfbridgeStartRecordAction.Create(const AConference: string;
  const ARecordFile: string);
begin
  inherited Create('ConfbridgeStartRecord');
  AddField('Conference', AConference);
  if ARecordFile <> '' then
    AddField('RecordFile', ARecordFile);
end;

{ TAMIConfbridgeStopRecordAction }

constructor TAMIConfbridgeStopRecordAction.Create(const AConference: string);
begin
  inherited Create('ConfbridgeStopRecord');
  AddField('Conference', AConference);
end;

{ TAMIConfbridgeSetSingleVideoSrcAction }

constructor TAMIConfbridgeSetSingleVideoSrcAction.Create(
  const AConference, AChannel: string);
begin
  inherited Create('ConfbridgeSetSingleVideoSrc');
  AddField('Conference', AConference);
  AddField('Channel', AChannel);
end;

{ TAMIMeetmeListAction }

constructor TAMIMeetmeListAction.Create(const AConference: string);
begin
  inherited Create('MeetmeList');
  if AConference <> '' then
    AddField('Conference', AConference);
end;

{ TAMIMeetmeListRoomsAction }

constructor TAMIMeetmeListRoomsAction.Create;
begin
  inherited Create('MeetmeListRooms');
end;

{ TAMIMeetmeMuteAction }

constructor TAMIMeetmeMuteAction.Create(const AMeetme, AUsernum: string);
begin
  inherited Create('MeetmeMute');
  AddField('Meetme', AMeetme);
  AddField('Usernum', AUsernum);
end;

{ TAMIMeetmeUnmuteAction }

constructor TAMIMeetmeUnmuteAction.Create(const AMeetme, AUsernum: string);
begin
  inherited Create('MeetmeUnmute');
  AddField('Meetme', AMeetme);
  AddField('Usernum', AUsernum);
end;

{ TAMIPJSIPNotifyAction }

constructor TAMIPJSIPNotifyAction.Create(const AEndpoint, AVariable: string);
begin
  inherited Create('PJSIPNotify');
  AddField('Endpoint', AEndpoint);
  AddField('Variable', AVariable);
end;

{ TAMIPJSIPQualifyAction }

constructor TAMIPJSIPQualifyAction.Create(const AEndpoint: string);
begin
  inherited Create('PJSIPQualify');
  AddField('Endpoint', AEndpoint);
end;

{ TAMIPJSIPShowEndpointsAction }

constructor TAMIPJSIPShowEndpointsAction.Create;
begin
  inherited Create('PJSIPShowEndpoints');
end;

{ TAMIPJSIPShowEndpointAction }

constructor TAMIPJSIPShowEndpointAction.Create(const AEndpoint: string);
begin
  inherited Create('PJSIPShowEndpoint');
  AddField('Endpoint', AEndpoint);
end;

{ TAMIPJSIPShowRegistrationInboundContactStatusesAction }

constructor TAMIPJSIPShowRegistrationInboundContactStatusesAction.Create;
begin
  inherited Create('PJSIPShowRegistrationInboundContactStatuses');
end;

{ TAMIPJSIPShowRegistrationsInboundAction }

constructor TAMIPJSIPShowRegistrationsInboundAction.Create;
begin
  inherited Create('PJSIPShowRegistrationsInbound');
end;

{ TAMIPJSIPShowRegistrationsOutboundAction }

constructor TAMIPJSIPShowRegistrationsOutboundAction.Create;
begin
  inherited Create('PJSIPShowRegistrationsOutbound');
end;

{ TAMIPJSIPShowResourceListsAction }

constructor TAMIPJSIPShowResourceListsAction.Create;
begin
  inherited Create('PJSIPShowResourceLists');
end;

{ TAMIPJSIPShowSubscriptionsInboundAction }

constructor TAMIPJSIPShowSubscriptionsInboundAction.Create;
begin
  inherited Create('PJSIPShowSubscriptionsInbound');
end;

{ TAMIPJSIPShowSubscriptionsOutboundAction }

constructor TAMIPJSIPShowSubscriptionsOutboundAction.Create;
begin
  inherited Create('PJSIPShowSubscriptionsOutbound');
end;

{ TAMISIPnotifyAction }

constructor TAMISIPnotifyAction.Create(const AChannel, AVariable: string);
begin
  inherited Create('SIPnotify');
  AddField('Channel', AChannel);
  AddField('Variable', AVariable);
end;

{ TAMISIPpeersAction }

constructor TAMISIPpeersAction.Create;
begin
  inherited Create('SIPpeers');
end;

{ TAMISIPshowpeerAction }

constructor TAMISIPshowpeerAction.Create(const APeer: string);
begin
  inherited Create('SIPshowpeer');
  AddField('Peer', APeer);
end;

{ TAMISIPshowregistryAction }

constructor TAMISIPshowregistryAction.Create;
begin
  inherited Create('SIPshowregistry');
end;

{ TAMISIPqualifypeerAction }

constructor TAMISIPqualifypeerAction.Create(const APeer: string);
begin
  inherited Create('SIPqualifypeer');
  AddField('Peer', APeer);
end;

{ TAMIVoicemailUsersListAction }

constructor TAMIVoicemailUsersListAction.Create;
begin
  inherited Create('VoicemailUsersList');
end;

{ TAMIMailboxStatusAction }

constructor TAMIMailboxStatusAction.Create(const AMailbox: string);
begin
  inherited Create('MailboxStatus');
  AddField('Mailbox', AMailbox);
end;

{ TAMIMailboxCountAction }

constructor TAMIMailboxCountAction.Create(const AMailbox: string);
begin
  inherited Create('MailboxCount');
  AddField('Mailbox', AMailbox);
end;

{ TAMIPingAction }

constructor TAMIPingAction.Create;
begin
  inherited Create('Ping');
end;

{ TAMIEventsAction }

constructor TAMIEventsAction.Create(const AEventMask: string);
begin
  inherited Create('Events');
  AddField('EventMask', AEventMask);
end;

{ TAMILogoffAction }

constructor TAMILogoffAction.Create;
begin
  inherited Create('Logoff');
end;

{ TAMIChallengeAction }

constructor TAMIChallengeAction.Create(const AAuthType: string);
begin
  inherited Create('Challenge');
  AddField('AuthType', AAuthType);
end;

{ TAMILoginAction }

constructor TAMILoginAction.Create(const AUsername, APassword: string;
  const AAuthType: string);
begin
  inherited Create('Login');
  AddField('Username', AUsername);
  if SameText(AAuthType, 'MD5') then
  begin
    AddField('AuthType', 'MD5');
    AddField('Key', APassword);
  end
  else
  begin
    if (AAuthType <> '') and not SameText(AAuthType, 'plain') and not
      SameText(AAuthType, 'plaintext') then
      AddField('AuthType', AAuthType);
    AddField('Secret', APassword);
  end;
end;

{ TAMICoreShowChannelsAction }

constructor TAMICoreShowChannelsAction.Create;
begin
  inherited Create('CoreShowChannels');
end;

{ TAMICoreStatusAction }

constructor TAMICoreStatusAction.Create;
begin
  inherited Create('CoreStatus');
end;

{ TAMICoreSettingsAction }

constructor TAMICoreSettingsAction.Create;
begin
  inherited Create('CoreSettings');
end;

{ TAMIReloadAction }

constructor TAMIReloadAction.Create(const AModule: string);
begin
  inherited Create('Reload');
  if AModule <> '' then
    AddField('Module', AModule);
end;

{ TAMIModuleLoadAction }

constructor TAMIModuleLoadAction.Create(const AModule: string; const ALoadType: string);
begin
  inherited Create('ModuleLoad');
  AddField('Module', AModule);
  AddField('LoadType', ALoadType);
end;

{ TAMIModuleCheckAction }

constructor TAMIModuleCheckAction.Create(const AModule: string);
begin
  inherited Create('ModuleCheck');
  AddField('Module', AModule);
end;

{ TAMIExtensionStateListAction }

constructor TAMIExtensionStateListAction.Create;
begin
  inherited Create('ExtensionStateList');
end;

{ TAMIExtensionStateAction }

constructor TAMIExtensionStateAction.Create(const AExtension: String; AContext: string);
begin
  inherited Create('ExtensionState');
  AddField('Exten', AExtension);
  AddField('Context', AContext);
end;

{ TAMIMonitorAction }

constructor TAMIMonitorAction.Create(const AChannel, AFile: string;
  const AFormat: string; AMix: boolean);
begin
  inherited Create('Monitor');
  AddField('Channel', AChannel);
  AddField('File', AFile);
  if AFormat <> '' then
    AddField('Format', AFormat);
  AddField('Mix', IfThen(AMix, 'true', 'false'));
end;

{ TAMIStopMonitorAction }

constructor TAMIStopMonitorAction.Create(const AChannel: string);
begin
  inherited Create('StopMonitor');
  AddField('Channel', AChannel);
end;

{ TAMIPauseMonitorAction }

constructor TAMIPauseMonitorAction.Create(const AChannel: string);
begin
  inherited Create('PauseMonitor');
  AddField('Channel', AChannel);
end;

{ TAMIUnpauseMonitorAction }

constructor TAMIUnpauseMonitorAction.Create(const AChannel: string);
begin
  inherited Create('UnpauseMonitor');
  AddField('Channel', AChannel);
end;

{ TAMIChangeMonitorAction }

constructor TAMIChangeMonitorAction.Create(const AChannel, AFile: string);
begin
  inherited Create('ChangeMonitor');
  AddField('Channel', AChannel);
  AddField('File', AFile);
end;

{ TAMIMixMonitorAction }

constructor TAMIMixMonitorAction.Create(const AChannel, AFile: string;
  const AOptions: string);
begin
  inherited Create('MixMonitor');
  AddField('Channel', AChannel);
  AddField('File', AFile);
  if AOptions <> '' then
    AddField('Options', AOptions);
end;

{ TAMIMixMonitorMuteAction }

constructor TAMIMixMonitorMuteAction.Create(const AChannel: string;
  const ADirection: string; AState: boolean);
begin
  inherited Create('MixMonitorMute');
  AddField('Channel', AChannel);
  AddField('Direction', ADirection);
  AddField('State', IfThen(AState, '1', '0'));
end;

{ TAMIStopMixMonitorAction }

constructor TAMIStopMixMonitorAction.Create(const AChannel: string;
  const AMixMonitorID: string);
begin
  inherited Create('StopMixMonitor');
  AddField('Channel', AChannel);
  if AMixMonitorID <> '' then
    AddField('MixMonitorID', AMixMonitorID);
end;

{ TAMIGetConfigAction }

constructor TAMIGetConfigAction.Create(const AFilename: string; const ACategory: string);
begin
  inherited Create('GetConfig');
  AddField('Filename', AFilename);
  if ACategory <> '' then
    AddField('Category', ACategory);
end;

{ TAMIGetConfigJSONAction }

constructor TAMIGetConfigJSONAction.Create(const AFilename: string);
begin
  inherited Create('GetConfigJSON');
  AddField('Filename', AFilename);
end;

{ TAMIUpdateConfigAction }

constructor TAMIUpdateConfigAction.Create(const ASrcFilename, ADstFilename: string);
begin
  inherited Create('UpdateConfig');
  AddField('SrcFilename', ASrcFilename);
  AddField('DstFilename', ADstFilename);
end;

{ TAMICreateConfigAction }

constructor TAMICreateConfigAction.Create(const AFilename: string);
begin
  inherited Create('CreateConfig');
  AddField('Filename', AFilename);
end;

{ TAMIListCategoriesAction }

constructor TAMIListCategoriesAction.Create(const AFilename: string);
begin
  inherited Create('ListCategories');
  AddField('Filename', AFilename);
end;

{ TAMIBridgeInfoAction }

constructor TAMIBridgeInfoAction.Create(const ABridgeUniqueid: string);
begin
  inherited Create('BridgeInfo');
  AddField('BridgeUniqueid', ABridgeUniqueid);
end;

{ TAMIBridgeListAction }

constructor TAMIBridgeListAction.Create(const ABridgeType: string);
begin
  inherited Create('BridgeList');
  if ABridgeType <> '' then
    AddField('BridgeType', ABridgeType);
end;

{ TAMIBridgeDestroyAction }

constructor TAMIBridgeDestroyAction.Create(const ABridgeUniqueid: string);
begin
  inherited Create('BridgeDestroy');
  AddField('BridgeUniqueid', ABridgeUniqueid);
end;

{ TAMIBridgeKickAction }

constructor TAMIBridgeKickAction.Create(const ABridgeUniqueid, AChannel: string);
begin
  inherited Create('BridgeKick');
  AddField('BridgeUniqueid', ABridgeUniqueid);
  AddField('Channel', AChannel);
end;

{ TAMIAgentLogoffAction }

constructor TAMIAgentLogoffAction.Create(const AAgent: string; ASoft: boolean);
begin
  inherited Create('AgentLogoff');
  AddField('Agent', AAgent);
  AddField('Soft', IfThen(ASoft, 'true', 'false'));
end;

{ TAMIAgentsAction }

constructor TAMIAgentsAction.Create;
begin
  inherited Create('Agents');
end;

{ TAMIUserEventAction }

constructor TAMIUserEventAction.Create(const AUserEvent: string);
begin
  inherited Create('UserEvent');
  AddField('UserEvent', AUserEvent);
end;

procedure TAMIUserEventAction.AddHeader(const AKey, AValue: string);
begin
  AddField(AKey, AValue);
end;

{ TAMIWaitEventAction }

constructor TAMIWaitEventAction.Create(ATimeout: integer);
begin
  inherited Create('WaitEvent');
  AddField('Timeout', IntToStr(ATimeout div 1000));
end;

{ TAMIShowDialPlanAction }

constructor TAMIShowDialPlanAction.Create(const AContext: string;
  const AExtension: string);
begin
  inherited Create('ShowDialPlan');
  if AContext <> '' then
    AddField('Context', AContext);
  if AExtension <> '' then
    AddField('Extension', AExtension);
end;

{ TAMIDataGetAction }

constructor TAMIDataGetAction.Create(const APath: string; const ASearch: string;
  const AFilter: string);
begin
  inherited Create('DataGet');
  AddField('Path', APath);
  if ASearch <> '' then
    AddField('Search', ASearch);
  if AFilter <> '' then
    AddField('Filter', AFilter);
end;

{ TAMIFilterAction }

constructor TAMIFilterAction.Create(const AOperation: string; const AFilter: string);
begin
  inherited Create('Filter');
  AddField('Operation', AOperation);
  AddField('Filter', AFilter);
end;

{ TAMIBlindTransferAction }

constructor TAMIBlindTransferAction.Create(const AChannel, AContext, AExten: string);
begin
  inherited Create('BlindTransfer');
  AddField('Channel', AChannel);
  AddField('Context', AContext);
  AddField('Exten', AExten);
end;

{ TAMICancelAtxferAction }

constructor TAMICancelAtxferAction.Create(const AChannel: string);
begin
  inherited Create('CancelAtxfer');
  AddField('Channel', AChannel);
end;

{ TPendingAction }

constructor TPendingAction.Create(AAction: TAMIAction);
begin
  inherited Create;
  FAction := AAction;
  FActionID := AAction.GetField('ActionID');
  if FActionID = '' then
    FActionID := TAMIUtils.GenerateActionID;
  FAction.AddField('ActionID', FActionID);

  if (AAction is TAMIDBGetAction) or (AAction is TAMIDBGetTreeAction) then
    FResponse := TAMIDBGetResponse.Create
  else if AAction is TAMICommandAction then
    FResponse := TAMICommandResponse.Create
  else
    FResponse := TAMIResponse.Create;

  FCreateTime := Now;
  FWaitEvent := TSimpleEvent.Create;
end;

destructor TPendingAction.Destroy;
begin
  FreeAndNil(FResponse);
  FreeAndNil(FWaitEvent);
  inherited Destroy;
end;

procedure TPendingAction.SignalDone;
begin
  FWaitEvent.SetEvent;
end;

function TPendingAction.Wait(ATimeout: cardinal): TWaitResult;
begin
  Result := FWaitEvent.WaitFor(ATimeout);
end;

{ TAMIDBGetAction }
constructor TAMIDBGetAction.Create(const AFamily, AKey: string);
begin
  inherited Create('DBGet');
  AddField('Family', AFamily);
  AddField('Key', AKey);
end;

{ TAMIDBPutAction }
constructor TAMIDBPutAction.Create(const AFamily, AKey, AVal: string);
begin
  inherited Create('DBPut');
  AddField('Family', AFamily);
  AddField('Key', AKey);
  AddField('Val', AVal);
end;

{ TAMIDBDelAction }
constructor TAMIDBDelAction.Create(const AFamily, AKey: string);
begin
  inherited Create('DBDel');
  AddField('Family', AFamily);
  AddField('Key', AKey);
end;

{ TAMIDBDelTreeAction }
constructor TAMIDBDelTreeAction.Create(const AFamily, AKey: string);
begin
  inherited Create('DBDelTree');
  AddField('Family', AFamily);
  AddField('Key', AKey);
end;

{ TAMIDBGetTreeAction }
constructor TAMIDBGetTreeAction.Create(const AFamily, AKey: string);
begin
  inherited Create('DBGetTree');
  AddField('Family', AFamily);
  AddField('Key', AKey);
end;



end.
