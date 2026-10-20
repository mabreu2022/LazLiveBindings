unit uLiveBindingsRegister;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  IDEWindowIntf, MenuIntf, IDECommands, PropEdits, ComponentEditors,
  uBindingRuntime, uBindingPropEditors, uBindingComponentEditor, uBindingDesignerForm;

procedure Register;

implementation

procedure Register;
begin
  // 1. Register Runtime Component in Component Palette
  RegisterComponents('LiveBindings', [TBindingManager]);

  // 2. Register Property Editors for Object Inspector
  RegisterPropertyEditor(TypeInfo(string), TBindingLink, 'SourceProperty', TBindingPropertySelectorEditor);
  RegisterPropertyEditor(TypeInfo(string), TBindingLink, 'TargetProperty', TBindingPropertySelectorEditor);
  RegisterPropertyEditor(TypeInfo(string), TBindingLink, 'SourceExpression', TBindingExpressionEditor);

  // 3. Register Context Menu Component Editor for form controls
  RegisterComponentEditor(TComponent, TBindingComponentEditor);

  // 4. Register IDE Menu item under View -> Secondary Windows
  RegisterIDEMenuCommand(itmViewSecondaryWindows, 'itmLiveBindingDesigner', 'LiveBinding Designer', nil, @ShowLiveBindingDesigner);

  // 5. Register Dockable Window Creator
  LiveBindingDesignerCreator := IDEWindowCreators.Add(LiveBindingDesignerName, @CreateLiveBindingDesigner, nil,
    '200', '150', '+840', '+560');
end;

end.
