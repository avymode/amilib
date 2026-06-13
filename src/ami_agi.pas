unit ami_agi;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, ami_actions, ami_utils, ami_types;

type
  // AMI: Action=AGI
  // Fields:
  //   Channel:   <channel>
  //   Command:   <AGI/AsyncAGI command string>
  //   CommandID: <id> (optional but recommended)
  TAMIAGIAction = class(TAMIAction)
  public
    constructor Create(const Channel, Command, CommandID: string);

    // Raw Exec
    class function Exec(const Channel, Command: string; const CommandID: string = ''): TAMIAGIAction;

    // Exec application with args: 'EXEC <AppName> <Args>'
    class function ExecApp(const Channel, AppName: string; const Args: string = ''; const CommandID: string = ''): TAMIAGIAction;

    // Helpers for common operations
    class function StartMOH(const Channel: string; const MusicClass: string = 'default'; const CommandID: string = ''): TAMIAGIAction;
    class function StopMOH(const Channel: string; const CommandID: string = ''): TAMIAGIAction;
    class function Transfer(const Channel, Context, Extension: string; Priority: Integer = 1; const CommandID: string = ''): TAMIAGIAction;
  end;

implementation

{ TAMIAGIAction }

constructor TAMIAGIAction.Create(const Channel, Command, CommandID: string);
var
  Cid: string;
begin
  inherited Create('AGI');
  AddField('Channel', Channel);
  AddField('Command', Command);

  if CommandID <> '' then
    Cid := CommandID
  else
    Cid := TAMIUtils.GenerateActionID;

  AddField('CommandID', Cid);
end;

class function TAMIAGIAction.Exec(const Channel, Command: string; const CommandID: string): TAMIAGIAction;
begin
  Result := TAMIAGIAction.Create(Channel, Command, CommandID);
end;

class function TAMIAGIAction.ExecApp(const Channel, AppName: string; const Args: string; const CommandID: string): TAMIAGIAction;
var
  Cmd: string;
begin
  if Args <> '' then
    Cmd := Format('EXEC %s %s', [AppName, Args])
  else
    Cmd := Format('EXEC %s', [AppName]);

  Result := TAMIAGIAction.Create(Channel, Cmd, CommandID);
end;

class function TAMIAGIAction.StartMOH(const Channel: string; const MusicClass: string; const CommandID: string): TAMIAGIAction;
var
  Args: string;
begin
  if MusicClass <> '' then
    Args := MusicClass
  else
    Args := '';
  Result := ExecApp(Channel, 'StartMusicOnHold', Args, CommandID);
end;

class function TAMIAGIAction.StopMOH(const Channel: string; const CommandID: string): TAMIAGIAction;
begin
  Result := ExecApp(Channel, 'StopMusicOnHold', '', CommandID);
end;

class function TAMIAGIAction.Transfer(const Channel, Context, Extension: string; Priority: Integer; const CommandID: string): TAMIAGIAction;
var
  Arg: string;
begin
  Arg := Format('%s@%s,%d', [Extension, Context, Priority]);
  Result := ExecApp(Channel, 'Transfer', Arg, CommandID);
end;

end.
