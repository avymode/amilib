unit ami_action_factory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, ami_actions, ami_types, ami_enums;

type
  TActionClass = class of TAMIAction;
  TActionMap = specialize TDictionary<String, TActionClass>;

{==============================================================================}
{=== TAMIActionFactory ======================================================}
{==============================================================================}

  TAMIActionFactory = class
  private
    class var FActionMap: TActionMap;
    class procedure InitializeMap;
  public
    class function CreateAction(const AActionName: String): TAMIAction;
    class procedure RegisterAction(const AName: String; AActionClass: TActionClass);
  end;

implementation

{==============================================================================}
{=== TAMIActionFactory ======================================================}
{==============================================================================}

class procedure TAMIActionFactory.InitializeMap;
begin
  FActionMap := TActionMap.Create;
  FActionMap.Add('ORIGINATE', TAMIOriginateAction);
  FActionMap.Add('HANGUP', TAMIHangupAction);
  FActionMap.Add('COMMAND', TAMICommandAction);
  FActionMap.Add('QUEUEADD', TAMIQueueAddAction);
  FActionMap.Add('QUEUEREMOVE', TAMIQueueRemoveAction);
  FActionMap.Add('QUEUESTATUS', TAMIQueueStatusAction);
  FActionMap.Add('QUEUEPAUSE', TAMIQueuePauseAction);
  FActionMap.Add('QUEUEPENALTY', TAMIQueuePenaltyAction);
  FActionMap.Add('QUEUERELOAD', TAMIQueueReloadAction);
  FActionMap.Add('QUEUERESET', TAMIQueueResetAction);
  FActionMap.Add('QUEUERULE', TAMIQueueRuleAction);
  FActionMap.Add('QUEUESUMMARY', TAMIQueueSummaryAction);
  FActionMap.Add('REDIRECT', TAMIRedirectAction);
  FActionMap.Add('ATXFER', TAMIAtxferAction);
  FActionMap.Add('BRIDGE', TAMIBridgeAction);
  FActionMap.Add('PARK', TAMIParkAction);
  FActionMap.Add('PLAYDTMF', TAMIPlayDTMFAction);
  FActionMap.Add('SENDTEXT', TAMISendTextAction);
  FActionMap.Add('SETVAR', TAMISetVarAction);
  FActionMap.Add('GETVAR', TAMIGetVarAction);
  FActionMap.Add('CONFBRIDGEKICK', TAMIConfbridgeKickAction);
  FActionMap.Add('CONFBRIDGELIST', TAMIConfbridgeListAction);
  FActionMap.Add('CONFBRIDGELISTROOMS', TAMIConfbridgeListRoomsAction);
  FActionMap.Add('CONFBRIDGELOCK', TAMIConfbridgeLockAction);
  FActionMap.Add('CONFBRIDGEUNLOCK', TAMIConfbridgeUnlockAction);
  FActionMap.Add('CONFBRIDGEMUTE', TAMIConfbridgeMuteAction);
  FActionMap.Add('CONFBRIDGEUNMUTE', TAMIConfbridgeUnmuteAction);
  FActionMap.Add('CONFBRIDGESTARTRECORD', TAMIConfbridgeStartRecordAction);
  FActionMap.Add('CONFBRIDGESTOPRECORD', TAMIConfbridgeStopRecordAction);
  FActionMap.Add('CONFBRIDGESETSINGLEVIDEOSRC', TAMIConfbridgeSetSingleVideoSrcAction);
  FActionMap.Add('MEETMELIST', TAMIMeetmeListAction);
  FActionMap.Add('MEETMELISTROOMS', TAMIMeetmeListRoomsAction);
  FActionMap.Add('MEETMEMUTE', TAMIMeetmeMuteAction);
  FActionMap.Add('MEETMEUNMUTE', TAMIMeetmeUnmuteAction);
  FActionMap.Add('PJSIPNOTIFY', TAMIPJSIPNotifyAction);
  FActionMap.Add('PJSIPQUALIFY', TAMIPJSIPQualifyAction);
  FActionMap.Add('PJSIPSHOWENDPOINTS', TAMIPJSIPShowEndpointsAction);
  FActionMap.Add('PJSIPSHOWENDPOINT', TAMIPJSIPShowEndpointAction);
  FActionMap.Add('PJSIPSHOWREGISTRATIONINBOUNDCONTACTSTATUSES', TAMIPJSIPShowRegistrationInboundContactStatusesAction);
  FActionMap.Add('PJSIPSHOWREGISTRATIONSINBOUND', TAMIPJSIPShowRegistrationsInboundAction);
  FActionMap.Add('PJSIPSHOWREGISTRATIONSOUTBOUND', TAMIPJSIPShowRegistrationsOutboundAction);
  FActionMap.Add('PJSIPSHOWRESOURCELISTS', TAMIPJSIPShowResourceListsAction);
  FActionMap.Add('PJSIPSHOWSUBSCRIPTIONSINBOUND', TAMIPJSIPShowSubscriptionsInboundAction);
  FActionMap.Add('PJSIPSHOWSUBSCRIPTIONSOUTBOUND', TAMIPJSIPShowSubscriptionsOutboundAction);
  FActionMap.Add('SIPNOTIFY', TAMISIPnotifyAction);
  FActionMap.Add('SIPPEERS', TAMISIPpeersAction);
  FActionMap.Add('SIPSHOWPEER', TAMISIPshowpeerAction);
  FActionMap.Add('SIPSHOWREGISTRY', TAMISIPshowregistryAction);
  FActionMap.Add('SIPQUALIFYPEER', TAMISIPqualifypeerAction);
  FActionMap.Add('VOICEMAILUSERSLIST', TAMIVoicemailUsersListAction);
  FActionMap.Add('MAILBOXSTATUS', TAMIMailboxStatusAction);
  FActionMap.Add('MAILBOXCOUNT', TAMIMailboxCountAction);
  FActionMap.Add('PING', TAMIPingAction);
  FActionMap.Add('EVENTS', TAMIEventsAction);
  FActionMap.Add('LOGOFF', TAMILogoffAction);
  FActionMap.Add('CHALLENGE', TAMIChallengeAction);
  FActionMap.Add('LOGIN', TAMILoginAction);
  FActionMap.Add('CORESHOWCHANNELS', TAMICoreShowChannelsAction);
  FActionMap.Add('CORESTATUS', TAMICoreStatusAction);
  FActionMap.Add('CORESETTINGS', TAMICoreSettingsAction);
  FActionMap.Add('RELOAD', TAMIReloadAction);
  FActionMap.Add('MODULELOAD', TAMIModuleLoadAction);
  FActionMap.Add('MODULECHECK', TAMIModuleCheckAction);
  FActionMap.Add('MONITOR', TAMIMonitorAction);
  FActionMap.Add('STOPMONITOR', TAMIStopMonitorAction);
  FActionMap.Add('PAUSEMONITOR', TAMIPauseMonitorAction);
  FActionMap.Add('UNPAUSEMONITOR', TAMIUnpauseMonitorAction);
  FActionMap.Add('CHANGEMONITOR', TAMIChangeMonitorAction);
  FActionMap.Add('MIXMONITOR', TAMIMixMonitorAction);
  FActionMap.Add('MIXMONITORMUTE', TAMIMixMonitorMuteAction);
  FActionMap.Add('STOPMIXMONITOR', TAMIStopMixMonitorAction);
  FActionMap.Add('GETCONFIG', TAMIGetConfigAction);
  FActionMap.Add('GETCONFIGJSON', TAMIGetConfigJSONAction);
  FActionMap.Add('UPDATECONFIG', TAMIUpdateConfigAction);
  FActionMap.Add('CREATECONFIG', TAMICreateConfigAction);
  FActionMap.Add('LISTCATEGORIES', TAMIListCategoriesAction);
  FActionMap.Add('BRIDGEINFO', TAMIBridgeInfoAction);
  FActionMap.Add('BRIDGELIST', TAMIBridgeListAction);
  FActionMap.Add('BRIDGEDESTROY', TAMIBridgeDestroyAction);
  FActionMap.Add('BRIDGEKICK', TAMIBridgeKickAction);
  FActionMap.Add('AGENTLOGOFF', TAMIAgentLogoffAction);
  FActionMap.Add('AGENTS', TAMIAgentsAction);
  FActionMap.Add('USEREVENT', TAMIUserEventAction);
  FActionMap.Add('WAITEVENT', TAMIWaitEventAction);
  FActionMap.Add('SHOWDIALPLAN', TAMIShowDialPlanAction);
  FActionMap.Add('DATAGET', TAMIDataGetAction);
  FActionMap.Add('FILTER', TAMIFilterAction);
  FActionMap.Add('BLINDTRANSFER', TAMIBlindTransferAction);
  FActionMap.Add('CANCELATXFER', TAMICancelAtxferAction);
  FActionMap.Add('DBGET', TAMIDBGetAction);
  FActionMap.Add('DBPUT', TAMIDBPutAction);
  FActionMap.Add('DBDEL', TAMIDBDelAction);
end;

class function TAMIActionFactory.CreateAction(const AActionName: String): TAMIAction;
var
  ActionClass: TActionClass;
begin
  if FActionMap.TryGetValue(UpperCase(AActionName), ActionClass) then
    Result := ActionClass.Create
  else
    Result := TAMIAction.Create(AActionName);
end;

class procedure TAMIActionFactory.RegisterAction(const AName: String; AActionClass: TActionClass);
begin
  FActionMap.AddOrSetValue(UpperCase(AName), AActionClass);
end;

initialization
  TAMIActionFactory.InitializeMap;

finalization
  TAMIActionFactory.FActionMap.Free;

end.
