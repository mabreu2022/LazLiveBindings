unit uBindingComponentEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ComponentEditors, Forms, PropEdits,
  uBindingRuntime, uBindingDesignerForm;

type
  { TBindingComponentEditor }

  TBindingComponentEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

implementation

{ TBindingComponentEditor }

function TBindingComponentEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TBindingComponentEditor.GetVerb(Index: Integer): string;
begin
  if Index = 0 then
    Result := 'Vincular com LiveBinding...'
  else
    Result := '';
end;

procedure TBindingComponentEditor.ExecuteVerb(Index: Integer);
var
  TargetComp: TComponent;
  OwnerForm: TComponent;
  Mgr: TBindingManager;
  i: Integer;
begin
  if Index <> 0 then
    Exit;

  TargetComp := GetComponent;
  if TargetComp = nil then
    Exit;

  OwnerForm := TargetComp.Owner;
  if OwnerForm = nil then
    Exit;

  // Search for an existing TBindingManager on the form
  Mgr := nil;
  for i := 0 to OwnerForm.ComponentCount - 1 do
  begin
    if OwnerForm.Components[i] is TBindingManager then
    begin
      Mgr := TBindingManager(OwnerForm.Components[i]);
      Break;
    end;
  end;

  // Create one if none exists
  if Mgr = nil then
  begin
    Mgr := TBindingManager.Create(OwnerForm);
    Mgr.Name := 'BindingManager1';
    if Assigned(GlobalDesignHook) then
      GlobalDesignHook.Modified(OwnerForm);
  end;

  // Open the visual designer window
  ShowLiveBindingDesigner(Self);

  // Focus the clicked component in the designer
  if LiveBindingDesignerForm <> nil then
    LiveBindingDesignerForm.SelectComponent(TargetComp);
end;

end.
