unit uLiveBindingsRegister;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls,
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

  // 3. Register Context Menu Component Editors
  RegisterComponentEditor(TBindingManager, TBindingManagerEditor);
  RegisterComponentEditor(TControl, TBindingControlEditor);

  // 4. Register IDE Menu item under View -> Secondary Windows
  RegisterIDEMenuCommand(itmViewSecondaryWindows, 'itmLiveBindingDesigner', 'LiveBinding Designer', nil, @ShowLiveBindingDesigner);

  // 5. Register Dockable Window Creator with standard bounds
  LiveBindingDesignerCreator := IDEWindowCreators.Add(LiveBindingDesignerName, @CreateLiveBindingDesigner, nil,
    '150', '150', '990', '710');
end;

end.
