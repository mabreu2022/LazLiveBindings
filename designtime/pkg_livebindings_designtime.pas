{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit pkg_livebindings_designtime;

{$warn 5023 off : no warning about unused units}
interface

uses
  uLiveBindingsRegister, uBindingPropEditors, uBindingComponentEditor,
  uBindingDesignerForm, uBindingExpressionDialog, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uLiveBindingsRegister', @uLiveBindingsRegister.Register);
end;

initialization
  RegisterPackage('pkg_livebindings_designtime', @Register);
end.
