{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit amilib;

{$warn 5023 off : no warning about unused units}
interface

uses
  ami_actions, ami_client, ami_connection, ami_events, ami_parser, ami_types, 
  ami_utils, ami_cache, ami_enums, ami_action_factory, ami_bus, ami_log, 
  ami_agi, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('amilib', @Register);
end.
