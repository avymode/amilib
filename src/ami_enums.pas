unit ami_enums;

{$mode objfpc}{$H+}

interface

type
  // AMI message types
  TAMIMessageType = (mtAction, mtResponse, mtEvent, mtWelcome);

  TConnectionEventType = (ceConnect, ceDisconnect);

  // Client status
  TAMIClientStatus = (csDisconnected, csConnecting, csConnected,
                      csAuthenticating, csAuthFailed, csReconnecting);

  // Authentication methods
  TAMIAuthorization = (amPlain, amMD5);

    TAgentCallState = (
    acsIdle,           // Нет активного вызова
    acsRinging,        // AgentCalled → оператору звонит
    acsAnswered,       // AgentConnect → оператор ответил
    acsOnHold,         // MusicOnHoldStart → абонент на холде
    acsCompleted,      // AgentComplete → разговор завершён
    acsNoAnswer,       // AgentRingNoAnswer → оператор не ответил
    acsDumped          // AgentDump → оператор отклонил
  );

  // COMPLETE AMI 16 EVENT TYPES (180+ events)
  TAMIEventType = (
    etUnknown,

    // === AGI Events ===
    etAGIExecEnd,
    etAGIExecStart,
    etAsyncAGIEnd,
    etAsyncAGIExec,
    etAsyncAGIStart,

    // === AOC (Advice of Charge) Events ===
    etAOC_D,
    etAOC_E,
    etAOC_S,

    // === Agent Events ===
    etAgentCalled,
    etAgentComplete,
    etAgentConnect,
    etAgentDump,
    etAgentLogin,
    etAgentLogoff,
    etAgentRingNoAnswer,
    etAgents,
    etAgentsComplete,

    // === Alarm Events ===
    etAlarm,
    etAlarmClear,
    etSpanAlarm,
    etSpanAlarmClear,

    // === AOR (Address of Record) Events ===
    etAorDetail,
    etAorList,
    etAorListComplete,

    // === Authentication Events ===
    etAuthDetail,
    etAuthList,
    etAuthListComplete,
    etAuthMethodNotAllowed,
    etChallengeResponseFailed,
    etChallengeSent,
    etFailedACL,
    etInvalidAccountID,
    etInvalidPassword,
    etInvalidTransport,
    etRequestBadFormat,
    etRequestNotAllowed,
    etRequestNotSupported,
    etSuccessfulAuth,
    etUnexpectedAddress,

    // === Bridge Events ===
    etBridgeCreate,
    etBridgeDestroy,
    etBridgeEnter,
    etBridgeInfoChannel,
    etBridgeInfoComplete,
    etBridgeLeave,
    etBridgeMerge,
    etBridgeVideoSourceUpdate,
    etLocalBridge,
    etLocalOptimizationBegin,
    etLocalOptimizationEnd,

    // === Call Detail Records ===
    etCEL,
    etCdr,

    // === Channel Events ===
    etChannelTalkingStart,
    etChannelTalkingStop,
    etCoreShowChannel,
    etCoreShowChannelsComplete,
    etDAHDIChannel,
    etDeviceStateChange,
    etDeviceStateListComplete,
    etDNDState,
    etExtensionStateListComplete,
    etExtensionStatus,
    etHangup,
    etHangupHandlerPop,
    etHangupHandlerPush,
    etHangupHandlerRun,
    etHangupRequest,
    etHold,
    etLogChannel,
    etMonitorStart,
    etMonitorStop,
    etMusicOnHoldStart,
    etMusicOnHoldStop,
    etNewAccountCode,
    etNewCallerid,
    etNewConnectedLine,
    etNewExten,
    etNewchannel,
    etNewstate,
    etOriginateResponse,
    etPickup,
    etRename,
    etSoftHangupRequest,
    etStatus,
    etStatusComplete,
    etUnhold,

    // === ConfBridge Events ===
    etConfbridgeEnd,
    etConfbridgeJoin,
    etConfbridgeLeave,
    etConfbridgeList,
    etConfbridgeListComplete,
    etConfbridgeListRooms,
    etConfbridgeMute,
    etConfbridgeRecord,
    etConfbridgeStart,
    etConfbridgeStopRecord,
    etConfbridgeTalking,
    etConfbridgeUnmute,

    // === Contact Events ===
    etContactList,
    etContactListComplete,
    etContactStatus,
    etContactStatusDetail,

    // === Dial Events ===
    etDialBegin,
    etDialEnd,
    etDialState,

    // === DTMF Events ===
    etDTMFBegin,
    etDTMFEnd,

    // === Endpoint Events ===
    etEndpointDetail,
    etEndpointDetailComplete,
    etEndpointList,
    etEndpointListComplete,
    etIdentifyDetail,
    etTransportDetail,

    // === FAX Events ===
    etFAXSession,
    etFAXSessionsComplete,
    etFAXSessionsEntry,
    etFAXStats,
    etFAXStatus,
    etReceiveFAX,
    etSendFAX,

    // === System Events ===
    etDeadlockStart,
    etFlash,
    etFullyBooted,
    etLoad,
    etLoadAverageLimit,
    etMemoryLimit,
    etReload,
    etSessionLimit,
    etSessionTimeout,
    etShutdown,
    etUnload,
    etWink,

    // === MeetMe Events ===
    etMeetmeEnd,
    etMeetmeJoin,
    etMeetmeLeave,
    etMeetmeList,
    etMeetmeListRooms,
    etMeetmeMute,
    etMeetmeTalkRequest,
    etMeetmeTalking,

    // === Message Waiting Indicator ===
    etMessageWaiting,
    etMiniVoiceMail,
    etMWIGet,
    etMWIGetComplete,

    // === MixMonitor Events ===
    etMixMonitorMute,
    etMixMonitorStart,
    etMixMonitorStop,

    // === Parked Call Events ===
    etParkedCall,
    etParkedCallGiveUp,
    etParkedCallSwap,
    etParkedCallTimeOut,
    etUnParkedCall,

    // === Peer Events ===
    etPeerStatus,
    etRegistry,
    etSIPQualifyPeerDone,

    // === Presence Events ===
    etPresenceStateChange,
    etPresenceStateListComplete,
    etPresenceStatus,

    // === Queue Events ===
    etQueueCallerAbandon,
    etQueueCallerJoin,
    etQueueCallerLeave,
    etQueueEntry,
    etQueueMember,
    etQueueMemberAdded,
    etQueueMemberPause,
    etQueueMemberPenalty,
    etQueueMemberRemoved,
    etQueueMemberRinginuse,
    etQueueMemberStatus,
    etQueueParams,
    etQueueStatusComplete,
    etQueueSummaryComplete,

    // === RTP/RTCP Events ===
    etRTCPReceived,
    etRTCPSent,

    // === Spy Events ===
    etChanSpyStart,
    etChanSpyStop,

    // === Transfer Events ===
    etAttendedTransfer,
    etBlindTransfer,

    // === User Events ===
    etUserEvent,

    // === Variable Events ===
    etVarSet,

    // === Miscellaneous ===
    etMCID,
    etChannelHungup,
    etChannelsHungupListComplete,

    // === AstBD ===
    etDBGetResponse,
    etDBGetComplete
  );

implementation

end.
