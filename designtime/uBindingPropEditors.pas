unit uBindingPropEditors;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PropEdits, TypInfo, Controls, Forms,
  uBindingRuntime, uBindingExpressionDialog;

type
  { TBindingPropertySelectorEditor }

  TBindingPropertySelectorEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  { TBindingExpressionEditor }

  TBindingExpressionEditor = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure Edit; override;
  end;

implementation

{ TBindingPropertySelectorEditor }

function TBindingPropertySelectorEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect];
end;

procedure TBindingPropertySelectorEditor.GetValues(Proc: TGetStrProc);
var
  Inst: TPersistent;
  Link: TBindingLink;
  Comp: TComponent;
  CurPropName: string;
  PropList: PPropList;
  PropInfo: PPropInfo;
  TotalProps, i: Integer;
begin
  Inst := GetComponent(0);
  if not (Inst is TBindingLink) then
    Exit;

  Link := TBindingLink(Inst);
  CurPropName := GetName;

  if SameText(CurPropName, 'SourceProperty') then
    Comp := Link.Source
  else if SameText(CurPropName, 'TargetProperty') then
    Comp := Link.Target
  else
    Comp := nil;

  if Comp = nil then
    Exit;

  TotalProps := GetPropList(Comp.ClassInfo, tkProperties, nil);
  if TotalProps > 0 then
  begin
    GetMem(PropList, TotalProps * SizeOf(PPropInfo));
    try
      GetPropList(Comp.ClassInfo, tkProperties, PropList);
      for i := 0 to TotalProps - 1 do
      begin
        PropInfo := PropList^[i];
        if SameText(CurPropName, 'SourceProperty') then
        begin
          if PropInfo^.GetProc <> nil then
            Proc(PropInfo^.Name);
        end
        else
        begin
          if PropInfo^.SetProc <> nil then
            Proc(PropInfo^.Name);
        end;
      end;
    finally
      FreeMem(PropList);
    end;
  end;
end;

{ TBindingExpressionEditor }

function TBindingExpressionEditor.GetAttributes: TPropertyAttributes;
begin
  Result := [paDialog];
end;

procedure TBindingExpressionEditor.Edit;
var
  Inst: TPersistent;
  Link: TBindingLink;
  Dlg: TBindingExpressionDialog;
begin
  Inst := GetComponent(0);
  if not (Inst is TBindingLink) then
  begin
    inherited Edit;
    Exit;
  end;

  Link := TBindingLink(Inst);
  Dlg := TBindingExpressionDialog.Create(Application);
  try
    Dlg.SetupDialog(Link.Source, Link.Target, GetStrValue);
    if Dlg.ShowModal = mrOk then
    begin
      SetStrValue(Dlg.Expression);
      Modified;
    end;
  finally
    Dlg.Free;
  end;
end;

end.
