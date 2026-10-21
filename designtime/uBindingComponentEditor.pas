unit uBindingComponentEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ComponentEditors, Forms, PropEdits,
  uBindingRuntime, uBindingDesignerForm;

type
  { TBindingManagerEditor }

  TBindingManagerEditor = class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
    procedure Edit; override;
  end;

  { TBindingControlEditor }

  TBindingControlEditor = class(TDefaultComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure ExecuteVerb(Index: Integer); override;
  end;

procedure ExecuteLiveBindingVerb(AComponent: TComponent);

implementation

procedure ExecuteLiveBindingVerb(AComponent: TComponent);
var
  TargetComp: TComponent;
  OwnerForm: TComponent;
  Mgr: TBindingManager;
  i: Integer;
begin
  TargetComp := AComponent;
  if TargetComp = nil then
    Exit;

  if TargetComp is TCustomForm then
    OwnerForm := TargetComp
  else
    OwnerForm := TargetComp.Owner;

  if (OwnerForm = nil) and (TargetComp is TComponent) then
    OwnerForm := TargetComp;

  // Search for an existing TBindingManager on the form
  Mgr := nil;
  if TargetComp is TBindingManager then
    Mgr := TBindingManager(TargetComp)
  else if OwnerForm <> nil then
  begin
    for i := 0 to OwnerForm.ComponentCount - 1 do
    begin
      if OwnerForm.Components[i] is TBindingManager then
      begin
        Mgr := TBindingManager(OwnerForm.Components[i]);
        Break;
      end;
    end;
  end;

  // Create one if none exists
  if (Mgr = nil) and (OwnerForm <> nil) then
  begin
    Mgr := TBindingManager.Create(OwnerForm);
    Mgr.Name := 'BindingManager1';
    if Assigned(GlobalDesignHook) then
      GlobalDesignHook.Modified(OwnerForm);
  end;

  // Open the visual designer window
  ShowLiveBindingDesigner(nil);

  // Focus the clicked component in the designer
  if LiveBindingDesignerForm <> nil then
    LiveBindingDesignerForm.SelectComponent(TargetComp);
end;

{ TBindingManagerEditor }

function TBindingManagerEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TBindingManagerEditor.GetVerb(Index: Integer): string;
begin
  if Index = 0 then
    Result := 'Abrir LiveBindings Visual Designer...'
  else
    Result := '';
end;

procedure TBindingManagerEditor.ExecuteVerb(Index: Integer);
begin
  if Index = 0 then
    ExecuteLiveBindingVerb(GetComponent);
end;

procedure TBindingManagerEditor.Edit;
begin
  ExecuteVerb(0);
end;

{ TBindingControlEditor }

function TBindingControlEditor.GetVerbCount: Integer;
begin
  Result := inherited GetVerbCount + 1;
end;

function TBindingControlEditor.GetVerb(Index: Integer): string;
var
  BaseCount: Integer;
begin
  BaseCount := inherited GetVerbCount;
  if Index < BaseCount then
    Result := inherited GetVerb(Index)
  else if Index = BaseCount then
    Result := 'Vincular com LiveBinding...'
  else
    Result := '';
end;

procedure TBindingControlEditor.ExecuteVerb(Index: Integer);
var
  BaseCount: Integer;
begin
  BaseCount := inherited GetVerbCount;
  if Index < BaseCount then
    inherited ExecuteVerb(Index)
  else if Index = BaseCount then
    ExecuteLiveBindingVerb(GetComponent);
end;

end.
