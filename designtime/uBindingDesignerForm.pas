unit uBindingDesignerForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids, Buttons, Menus, TypInfo,
  PropEdits, IDEWindowIntf,
  uBindingRuntime, uBindingExpressionDialog;

const
  LiveBindingDesignerName = 'LiveBindingDesignerForm';

type

  { TLiveBindingDesignerForm }

  TLiveBindingDesignerForm = class(TForm)
    pnlToolbar: TPanel;
    btnNewDirect: TBitBtn;
    btnNewExpr: TBitBtn;
    btnEditExpr: TBitBtn;
    btnDeleteLink: TBitBtn;
    btnSyncNow: TBitBtn;
    btnToggleActive: TBitBtn;
    lblActiveForm: TLabel;
    pnlMain: TPanel;
    pnlLeft: TPanel;
    splitterMain: TSplitter;
    pnlRight: TPanel;
    gbComponents: TGroupBox;
    edtFilterComp: TEdit;
    tvComponents: TTreeView;
    pnlTreeActions: TPanel;
    btnSetSource: TSpeedButton;
    btnSetTarget: TSpeedButton;
    lblSelectedSource: TLabel;
    lblSelectedTarget: TLabel;
    gbLinks: TGroupBox;
    sgLinks: TStringGrid;
    pmLinks: TPopupMenu;
    miEditExpr: TMenuItem;
    miToggleActive: TMenuItem;
    miSyncNow: TMenuItem;
    miDeleteLink: TMenuItem;
    miSep1: TMenuItem;
    miRefreshAll: TMenuItem;
    sbStatus: TStatusBar;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure edtFilterCompChange(Sender: TObject);
    procedure btnSetSourceClick(Sender: TObject);
    procedure btnSetTargetClick(Sender: TObject);
    procedure btnNewDirectClick(Sender: TObject);
    procedure btnNewExprClick(Sender: TObject);
    procedure btnEditExprClick(Sender: TObject);
    procedure btnDeleteLinkClick(Sender: TObject);
    procedure btnToggleActiveClick(Sender: TObject);
    procedure btnSyncNowClick(Sender: TObject);
    procedure sgLinksDblClick(Sender: TObject);
    procedure sgLinksSelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
    procedure tvComponentsSelectionChanged(Sender: TObject);
  private
    FSelectedSourceComp: TComponent;
    FSelectedSourceProp: string;
    FSelectedTargetComp: TComponent;
    FSelectedTargetProp: string;

    procedure OnDesignerSelectionChanged(const ASelection: TPersistentSelectionList);
    procedure OnComponentRenamed(AComponent: TComponent);
    procedure OnPersistentDeleted(APersistent: TPersistent);

    function GetCurrentRootForm: TComponent;
    function FindBindingManager(ARoot: TComponent; AAutoCreate: Boolean = False): TBindingManager;
    procedure RefreshComponentsTree;
    procedure RefreshLinksGrid;
    function GetSelectedLink: TBindingLink;
    procedure MarkFormModified;
  public
    procedure SelectComponent(AComponent: TComponent);
  end;

var
  LiveBindingDesignerForm: TLiveBindingDesignerForm = nil;
  LiveBindingDesignerCreator: TIDEWindowCreator = nil;

procedure ShowLiveBindingDesigner(Sender: TObject);
procedure CreateLiveBindingDesigner(Sender: TObject; aFormName: string;
  var AForm: TCustomForm; DoDisableAutoSizing: boolean);

implementation

{$R *.lfm}

procedure ShowLiveBindingDesigner(Sender: TObject);
begin
  IDEWindowCreators.ShowForm(LiveBindingDesignerName, True);
end;

procedure CreateLiveBindingDesigner(Sender: TObject; aFormName: string;
  var AForm: TCustomForm; DoDisableAutoSizing: boolean);
begin
  IDEWindowCreators.CreateForm(AForm, TLiveBindingDesignerForm, DoDisableAutoSizing, Application);
  AForm.Name := aFormName;
  LiveBindingDesignerForm := TLiveBindingDesignerForm(AForm);
end;

{ TLiveBindingDesignerForm }

procedure TLiveBindingDesignerForm.FormCreate(Sender: TObject);
begin
  LiveBindingDesignerForm := Self;

  // Initialize Grid headers
  sgLinks.Cells[0, 0] := '#';
  sgLinks.Cells[1, 0] := 'Ativo';
  sgLinks.Cells[2, 0] := 'Origem (Source)';
  sgLinks.Cells[3, 0] := 'Propriedade / Expressão';
  sgLinks.Cells[4, 0] := 'Direção';
  sgLinks.Cells[5, 0] := 'Destino (Target)';
  sgLinks.Cells[6, 0] := 'Propriedade Alvo';
  sgLinks.Cells[7, 0] := 'Modo';

  // Attach GlobalDesignHook handlers
  if Assigned(GlobalDesignHook) then
  begin
    GlobalDesignHook.AddHandlerSetSelection(@OnDesignerSelectionChanged);
    GlobalDesignHook.AddHandlerComponentRenamed(@OnComponentRenamed);
    GlobalDesignHook.AddHandlerPersistentDeleted(@OnPersistentDeleted);
  end;
end;

procedure TLiveBindingDesignerForm.FormDestroy(Sender: TObject);
begin
  if Assigned(GlobalDesignHook) then
    GlobalDesignHook.RemoveAllHandlersForObject(Self);

  if LiveBindingDesignerForm = Self then
    LiveBindingDesignerForm := nil;
end;

procedure TLiveBindingDesignerForm.FormShow(Sender: TObject);
begin
  RefreshComponentsTree;
  RefreshLinksGrid;
end;

function TLiveBindingDesignerForm.GetCurrentRootForm: TComponent;
begin
  Result := nil;
  if Assigned(GlobalDesignHook) and (GlobalDesignHook.LookupRoot is TComponent) then
    Result := TComponent(GlobalDesignHook.LookupRoot);
end;

function TLiveBindingDesignerForm.FindBindingManager(ARoot: TComponent; AAutoCreate: Boolean): TBindingManager;
var
  i: Integer;
begin
  Result := nil;
  if ARoot = nil then
    Exit;

  for i := 0 to ARoot.ComponentCount - 1 do
  begin
    if ARoot.Components[i] is TBindingManager then
    begin
      Result := TBindingManager(ARoot.Components[i]);
      Exit;
    end;
  end;

  if (Result = nil) and AAutoCreate then
  begin
    Result := TBindingManager.Create(ARoot);
    Result.Name := 'BindingManager1';
    MarkFormModified;
  end;
end;

procedure TLiveBindingDesignerForm.MarkFormModified;
var
  Root: TComponent;
begin
  Root := GetCurrentRootForm;
  if Assigned(GlobalDesignHook) and Assigned(Root) then
    GlobalDesignHook.Modified(Root);
end;

procedure TLiveBindingDesignerForm.OnDesignerSelectionChanged(const ASelection: TPersistentSelectionList);
var
  Comp: TComponent;
begin
  if (ASelection <> nil) and (ASelection.Count > 0) and (ASelection[0] is TComponent) then
  begin
    Comp := TComponent(ASelection[0]);
    SelectComponent(Comp);
  end;
  RefreshLinksGrid;
end;

procedure TLiveBindingDesignerForm.OnComponentRenamed(AComponent: TComponent);
begin
  RefreshComponentsTree;
  RefreshLinksGrid;
end;

procedure TLiveBindingDesignerForm.OnPersistentDeleted(APersistent: TPersistent);
begin
  if (APersistent <> nil) and (APersistent is TComponent) then
  begin
    if FSelectedSourceComp = TComponent(APersistent) then
    begin
      FSelectedSourceComp := nil;
      FSelectedSourceProp := '';
      lblSelectedSource.Caption := 'Origem: (nenhuma)';
    end;
    if FSelectedTargetComp = TComponent(APersistent) then
    begin
      FSelectedTargetComp := nil;
      FSelectedTargetProp := '';
      lblSelectedTarget.Caption := 'Destino: (nenhum)';
    end;
  end;
  RefreshComponentsTree;
  RefreshLinksGrid;
end;

procedure TLiveBindingDesignerForm.RefreshComponentsTree;
var
  Root: TComponent;
  i, j, PropCount: Integer;
  Comp: TComponent;
  CompNode, PropNode: TTreeNode;
  PropList: PPropList;
  PropInfo: PPropInfo;
  PName, TypeStr, FilterText: string;
begin
  tvComponents.Items.BeginUpdate;
  try
    tvComponents.Items.Clear;
    Root := GetCurrentRootForm;
    if Root = nil then
    begin
      lblActiveForm.Caption := 'Formulário Ativo: (nenhum no Designer)';
      Exit;
    end;

    lblActiveForm.Caption := 'Formulário Ativo: ' + Root.Name;
    FilterText := UpperCase(Trim(edtFilterComp.Text));

    for i := 0 to Root.ComponentCount - 1 do
    begin
      Comp := Root.Components[i];
      if (Comp = nil) or (Comp.Name = '') then
        Continue;

      if (FilterText <> '') and (Pos(FilterText, UpperCase(Comp.Name)) = 0) then
        Continue;

      CompNode := tvComponents.Items.AddObject(nil, Format('%s: %s', [Comp.Name, Comp.ClassName]), Comp);

      PropCount := GetPropList(Comp.ClassInfo, tkProperties, nil);
      if PropCount > 0 then
      begin
        GetMem(PropList, PropCount * SizeOf(PPropInfo));
        try
          GetPropList(Comp.ClassInfo, tkProperties, PropList);
          for j := 0 to PropCount - 1 do
          begin
            PropInfo := PropList^[j];
            if (PropInfo^.GetProc = nil) then
              Continue;

            PName := PropInfo^.Name;
            case PropInfo^.PropType^.Kind of
              tkInteger: TypeStr := 'Integer';
              tkInt64:   TypeStr := 'Int64';
              tkBool:    TypeStr := 'Boolean';
              tkFloat:   TypeStr := 'Float';
              tkChar, tkSString, tkLString, tkAString, tkWString, tkUString: TypeStr := 'String';
              tkEnumeration: TypeStr := 'Enum';
            else
              TypeStr := 'Outro';
            end;

            PropNode := tvComponents.Items.AddChildObject(CompNode, Format('%s (%s)', [PName, TypeStr]), Comp);
          end;
        finally
          FreeMem(PropList);
        end;
      end;
      CompNode.Expanded := False;
    end;
  finally
    tvComponents.Items.EndUpdate;
  end;
end;

procedure TLiveBindingDesignerForm.RefreshLinksGrid;
var
  Root: TComponent;
  Mgr: TBindingManager;
  i: Integer;
  Link: TBindingLink;
  SrcName, TgtName, DirStr, ModeStr, ActiveStr: string;
begin
  Root := GetCurrentRootForm;
  Mgr := FindBindingManager(Root, False);

  if (Mgr = nil) or (Mgr.Links.Count = 0) then
  begin
    sgLinks.RowCount := 2;
    sgLinks.Rows[1].Clear;
    sgLinks.Cells[0, 1] := '-';
    sgLinks.Cells[2, 1] := '(nenhum vínculo)';
    sgLinks.Objects[0, 1] := nil;
    sbStatus.Panels[0].Text := 'Nenhum vínculo configurado.';
    Exit;
  end;

  sgLinks.RowCount := Mgr.Links.Count + 1;
  sbStatus.Panels[0].Text := Format('%d vínculos encontrados no %s', [Mgr.Links.Count, Mgr.Name]);

  for i := 0 to Mgr.Links.Count - 1 do
  begin
    Link := Mgr.Links[i];

    if Link.Active then
      ActiveStr := 'SIM'
    else
      ActiveStr := 'NÃO';

    if Link.Source <> nil then
      SrcName := Link.Source.Name
    else
      SrcName := '(nenhuma)';

    if Link.Target <> nil then
      TgtName := Link.Target.Name
    else
      TgtName := '(nenhum)';

    case Link.Direction of
      bdSourceToTarget: DirStr := '-->';
      bdTargetToSource: DirStr := '<--';
      bdTwoWay:         DirStr := '<-->';
    end;

    case Link.Mode of
      bmDirectProperty: ModeStr := 'Direto';
      bmExpression:     ModeStr := 'Expressão';
    end;

    sgLinks.Cells[0, i + 1] := IntToStr(i + 1);
    sgLinks.Cells[1, i + 1] := ActiveStr;
    sgLinks.Cells[2, i + 1] := SrcName;

    if Link.Mode = bmDirectProperty then
      sgLinks.Cells[3, i + 1] := Link.SourceProperty
    else
      sgLinks.Cells[3, i + 1] := Link.SourceExpression;

    sgLinks.Cells[4, i + 1] := DirStr;
    sgLinks.Cells[5, i + 1] := TgtName;
    sgLinks.Cells[6, i + 1] := Link.TargetProperty;
    sgLinks.Cells[7, i + 1] := ModeStr;
    sgLinks.Objects[0, i + 1] := Link;
  end;
end;

function TLiveBindingDesignerForm.GetSelectedLink: TBindingLink;
var
  Row: Integer;
begin
  Result := nil;
  Row := sgLinks.Row;
  if (Row >= 1) and (Row < sgLinks.RowCount) and (sgLinks.Objects[0, Row] <> nil) then
    Result := TBindingLink(sgLinks.Objects[0, Row]);
end;

procedure TLiveBindingDesignerForm.SelectComponent(AComponent: TComponent);
var
  Node: TTreeNode;
begin
  if (AComponent = nil) or (tvComponents.Items.Count = 0) then
    Exit;

  Node := tvComponents.Items.GetFirstNode;
  while Node <> nil do
  begin
    if Node.Data = Pointer(AComponent) then
    begin
      tvComponents.Selected := Node;
      Node.MakeVisible;
      Exit;
    end;
    Node := Node.GetNext;
  end;
end;

procedure TLiveBindingDesignerForm.edtFilterCompChange(Sender: TObject);
begin
  RefreshComponentsTree;
end;

procedure TLiveBindingDesignerForm.tvComponentsSelectionChanged(Sender: TObject);
var
  Node: TTreeNode;
  Comp: TComponent;
  PureProp: string;
  P: Integer;
begin
  Node := tvComponents.Selected;
  if Node = nil then
    Exit;

  if Node.Parent <> nil then
  begin
    // It's a property node
    Comp := TComponent(Node.Data);
    PureProp := Node.Text;
    P := Pos(' (', PureProp);
    if P > 0 then
      PureProp := Copy(PureProp, 1, P - 1);

    sbStatus.Panels[1].Text := Format('Selecionado: %s.%s', [Comp.Name, PureProp]);
  end
  else if Node.Data <> nil then
  begin
    Comp := TComponent(Node.Data);
    sbStatus.Panels[1].Text := Format('Componente: %s (%s)', [Comp.Name, Comp.ClassName]);
  end;
end;

procedure TLiveBindingDesignerForm.btnSetSourceClick(Sender: TObject);
var
  Node: TTreeNode;
  P: Integer;
begin
  Node := tvComponents.Selected;
  if (Node = nil) or (Node.Parent = nil) then
  begin
    ShowMessage('Selecione uma propriedade na árvore para definir como Origem (Source).');
    Exit;
  end;

  FSelectedSourceComp := TComponent(Node.Data);
  FSelectedSourceProp := Node.Text;
  P := Pos(' (', FSelectedSourceProp);
  if P > 0 then
    FSelectedSourceProp := Copy(FSelectedSourceProp, 1, P - 1);

  lblSelectedSource.Caption := Format('Origem: %s.%s', [FSelectedSourceComp.Name, FSelectedSourceProp]);
end;

procedure TLiveBindingDesignerForm.btnSetTargetClick(Sender: TObject);
var
  Node: TTreeNode;
  P: Integer;
begin
  Node := tvComponents.Selected;
  if (Node = nil) or (Node.Parent = nil) then
  begin
    ShowMessage('Selecione uma propriedade na árvore para definir como Destino (Target).');
    Exit;
  end;

  FSelectedTargetComp := TComponent(Node.Data);
  FSelectedTargetProp := Node.Text;
  P := Pos(' (', FSelectedTargetProp);
  if P > 0 then
    FSelectedTargetProp := Copy(FSelectedTargetProp, 1, P - 1);

  lblSelectedTarget.Caption := Format('Destino: %s.%s', [FSelectedTargetComp.Name, FSelectedTargetProp]);
end;

procedure TLiveBindingDesignerForm.btnNewDirectClick(Sender: TObject);
var
  Root: TComponent;
  Mgr: TBindingManager;
  Link: TBindingLink;
begin
  if (FSelectedSourceComp = nil) or (FSelectedSourceProp = '') then
  begin
    ShowMessage('Defina primeiro a Origem (Source) selecionando uma propriedade e clicando em "Definir Origem".');
    Exit;
  end;

  if (FSelectedTargetComp = nil) or (FSelectedTargetProp = '') then
  begin
    ShowMessage('Defina primeiro o Destino (Target) selecionando uma propriedade e clicando em "Definir Destino".');
    Exit;
  end;

  Root := GetCurrentRootForm;
  if Root = nil then
  begin
    ShowMessage('Nenhum formulário ativo no designer.');
    Exit;
  end;

  Mgr := FindBindingManager(Root, True);
  Link := Mgr.AddLink(FSelectedSourceComp, FSelectedSourceProp, FSelectedTargetComp, FSelectedTargetProp);
  Link.Active := True;

  MarkFormModified;
  RefreshLinksGrid;
  ShowMessage(Format('Vínculo criado com sucesso!'#13#10'%s.%s -> %s.%s',
    [FSelectedSourceComp.Name, FSelectedSourceProp, FSelectedTargetComp.Name, FSelectedTargetProp]));
end;

procedure TLiveBindingDesignerForm.btnNewExprClick(Sender: TObject);
var
  Root: TComponent;
  Mgr: TBindingManager;
  Link: TBindingLink;
  Dlg: TBindingExpressionDialog;
  SrcComp, TgtComp: TComponent;
  TgtProp: string;
begin
  Root := GetCurrentRootForm;
  if Root = nil then
  begin
    ShowMessage('Nenhum formulário ativo no designer.');
    Exit;
  end;

  SrcComp := FSelectedSourceComp;
  if SrcComp = nil then
    SrcComp := Root;

  TgtComp := FSelectedTargetComp;
  TgtProp := FSelectedTargetProp;

  if (TgtComp = nil) or (TgtProp = '') then
  begin
    ShowMessage('Defina o Destino (Target) antes de criar um vínculo por expressão.');
    Exit;
  end;

  Dlg := TBindingExpressionDialog.Create(Application);
  try
    Dlg.SetupDialog(SrcComp, TgtComp, '');
    if Dlg.ShowModal = mrOk then
    begin
      Mgr := FindBindingManager(Root, True);
      Link := Mgr.AddExpressionLink(SrcComp, Dlg.Expression, TgtComp, TgtProp);
      Link.Active := True;

      MarkFormModified;
      RefreshLinksGrid;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TLiveBindingDesignerForm.btnEditExprClick(Sender: TObject);
var
  Link: TBindingLink;
  Dlg: TBindingExpressionDialog;
begin
  Link := GetSelectedLink;
  if Link = nil then
  begin
    ShowMessage('Selecione um vínculo na lista para editar.');
    Exit;
  end;

  Dlg := TBindingExpressionDialog.Create(Application);
  try
    Dlg.SetupDialog(Link.Source, Link.Target, Link.SourceExpression);
    if Dlg.ShowModal = mrOk then
    begin
      Link.Mode := bmExpression;
      Link.SourceExpression := Dlg.Expression;
      MarkFormModified;
      RefreshLinksGrid;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TLiveBindingDesignerForm.btnDeleteLinkClick(Sender: TObject);
var
  Link: TBindingLink;
  Mgr: TBindingManager;
begin
  Link := GetSelectedLink;
  if Link = nil then
  begin
    ShowMessage('Selecione um vínculo na lista para excluir.');
    Exit;
  end;

  if MessageDlg('Confirmação', 'Deseja realmente remover o vínculo selecionado?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Mgr := Link.OwnerManager;
    if Mgr <> nil then
      Mgr.RemoveLink(Link);

    MarkFormModified;
    RefreshLinksGrid;
  end;
end;

procedure TLiveBindingDesignerForm.btnToggleActiveClick(Sender: TObject);
var
  Link: TBindingLink;
begin
  Link := GetSelectedLink;
  if Link = nil then
    Exit;

  Link.Active := not Link.Active;
  MarkFormModified;
  RefreshLinksGrid;
end;

procedure TLiveBindingDesignerForm.btnSyncNowClick(Sender: TObject);
var
  Link: TBindingLink;
begin
  Link := GetSelectedLink;
  if Link <> nil then
  begin
    Link.Synchronize;
    if Link.LastError <> '' then
      ShowMessage('Erro ao sincronizar vínculo: ' + Link.LastError)
    else
      ShowMessage('Vínculo sincronizado com sucesso!');
  end;
end;

procedure TLiveBindingDesignerForm.sgLinksDblClick(Sender: TObject);
var
  Link: TBindingLink;
begin
  Link := GetSelectedLink;
  if Link = nil then
    Exit;

  if Link.Mode = bmExpression then
    btnEditExprClick(Sender)
  else
    btnToggleActiveClick(Sender);
end;

procedure TLiveBindingDesignerForm.sgLinksSelectCell(Sender: TObject; aCol, aRow: Integer; var CanSelect: Boolean);
begin
  CanSelect := True;
end;

end.
