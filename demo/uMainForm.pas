unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls, Spin, Grids, Buttons, uBindingRuntime;

type

  { TMainForm }

  TMainForm = class(TForm)
    BindingManager1: TBindingManager;
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    pcDemo: TPageControl;
    tsDirectBindings: TTabSheet;
    tsExpressionBindings: TTabSheet;
    tsManagerMonitor: TTabSheet;

    // Tab 1: Direct Bindings
    gbDirect1: TGroupBox;
    lblPromptNome: TLabel;
    edtNome: TEdit;
    lblDirectResultLabel: TLabel;
    lblNomeOutput: TLabel;

    gbDirect2: TGroupBox;
    lblPromptSlider: TLabel;
    tbVolume: TTrackBar;
    pbVolume: TProgressBar;
    lblVolumeVal: TLabel;

    gbDirect3: TGroupBox;
    chkEnableButton: TCheckBox;
    btnActionTarget: TButton;

    // Tab 2: Expression Bindings
    gbMathExpr: TGroupBox;
    lblPromptPreco: TLabel;
    sePreco: TFloatSpinEdit;
    lblPromptQtd: TLabel;
    seQtd: TSpinEdit;
    lblSubtotalTitle: TLabel;
    lblSubtotal: TLabel;
    lblTotalTaxTitle: TLabel;
    lblTotalWithTax: TLabel;
    lblMathFormula: TLabel;

    gbStringExpr: TGroupBox;
    lblPromptTexto: TLabel;
    edtTextoOriginal: TEdit;
    lblUpperTitle: TLabel;
    lblUpperResult: TLabel;
    lblTrimTitle: TLabel;
    lblTrimResult: TLabel;

    gbConditionalExpr: TGroupBox;
    chkVip: TCheckBox;
    lblConditionalResult: TLabel;

    // Tab 3: Monitor & Runtime Control
    pnlMonitorToolbar: TPanel;
    btnSyncAll: TBitBtn;
    btnToggleManagerActive: TBitBtn;
    btnClearLog: TBitBtn;
    btnAddRuntimeLink: TBitBtn;
    gbGrid: TGroupBox;
    sgActiveLinks: TStringGrid;
    gbLog: TGroupBox;
    mmoLog: TMemo;

    procedure FormCreate(Sender: TObject);
    procedure ControlChangeTrigger(Sender: TObject);
    procedure btnSyncAllClick(Sender: TObject);
    procedure btnToggleManagerActiveClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure btnAddRuntimeLinkClick(Sender: TObject);
    procedure BindingManager1BeforeSync(Sender: TObject; Link: TBindingLink);
    procedure BindingManager1AfterSync(Sender: TObject; Link: TBindingLink);
    procedure BindingManager1BindingError(Sender: TObject; Link: TBindingLink; const ErrorMsg: string);
  private
    procedure RefreshLinksGrid;
    procedure LogMessage(const Msg: string);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  L: TBindingLink;
begin
  // Set up events on BindingManager
  BindingManager1.OnBeforeSync := @BindingManager1BeforeSync;
  BindingManager1.OnAfterSync := @BindingManager1AfterSync;
  BindingManager1.OnBindingError := @BindingManager1BindingError;

  // Fallback programmatic setup only if links were not already loaded from .lfm
  if BindingManager1.Links.Count = 0 then
  begin
    // 1. Direct Binding: edtNome.Text -> lblNomeOutput.Caption
    L := BindingManager1.AddLink(edtNome, 'Text', lblNomeOutput, 'Caption');
    L.Active := True;

    // 2. Direct Binding: tbVolume.Position -> pbVolume.Position
    L := BindingManager1.AddLink(tbVolume, 'Position', pbVolume, 'Position');
    L.Active := True;

    // 3. Direct Binding: tbVolume.Position -> lblVolumeVal.Caption (with FormatMask)
    L := BindingManager1.AddLink(tbVolume, 'Position', lblVolumeVal, 'Caption');
    L.FormatMask := '%d%%';
    L.Active := True;

    // 4. Direct Binding: chkEnableButton.Checked -> btnActionTarget.Enabled
    L := BindingManager1.AddLink(chkEnableButton, 'Checked', btnActionTarget, 'Enabled');
    L.Active := True;

    // 5. Expression Binding: Math Subtotal (sePreco.Value * seQtd.Value)
    L := BindingManager1.AddExpressionLink(sePreco, 'Value * seQtd_Value', lblSubtotal, 'Caption');
    L.FormatMask := 'R$ #,##0.00';
    L.Active := True;

    // 6. Expression Binding: Total with 15% Tax (sePreco.Value * seQtd.Value * 1.15)
    L := BindingManager1.AddExpressionLink(sePreco, 'Value * seQtd_Value * 1.15', lblTotalWithTax, 'Caption');
    L.FormatMask := 'R$ #,##0.00';
    L.Active := True;

    // 7. Expression Binding: String UpperCase
    L := BindingManager1.AddExpressionLink(edtTextoOriginal, 'Upper(Text)', lblUpperResult, 'Caption');
    L.Active := True;

    // 8. Expression Binding: String Trim
    L := BindingManager1.AddExpressionLink(edtTextoOriginal, 'Trim(Text)', lblTrimResult, 'Caption');
    L.Active := True;

    // 9. Expression Binding: Conditional Logic
    L := BindingManager1.AddExpressionLink(chkVip, 'If(Checked, "⭐ CLIENTE VIP: 20% DE DESCONTO APLICADO", "CLIENTE REGULAR (SEM DESCONTO)")',
      lblConditionalResult, 'Caption');
    L.Active := True;
  end;

  // Initial synchronization
  BindingManager1.SynchronizeAll;
  RefreshLinksGrid;
  LogMessage('LiveBindings inicializado com sucesso.');
end;

procedure TMainForm.ControlChangeTrigger(Sender: TObject);
begin
  // Synchronize LiveBindings when controls are modified by user
  if Sender is TComponent then
    BindingManager1.SynchronizeSource(TComponent(Sender));

  // If one of the math controls changed, sync them both
  if (Sender = sePreco) or (Sender = seQtd) then
    BindingManager1.SynchronizeSource(sePreco);
end;

procedure TMainForm.btnSyncAllClick(Sender: TObject);
begin
  BindingManager1.SynchronizeAll;
  RefreshLinksGrid;
  LogMessage('Sincronização manual completa executada.');
end;

procedure TMainForm.btnToggleManagerActiveClick(Sender: TObject);
begin
  BindingManager1.Active := not BindingManager1.Active;
  if BindingManager1.Active then
  begin
    btnToggleManagerActive.Caption := 'Pausar LiveBindings';
    LogMessage('BindingManager ATIVADO.');
  end
  else
  begin
    btnToggleManagerActive.Caption := 'Ativar LiveBindings';
    LogMessage('BindingManager DESATIVADO.');
  end;
  RefreshLinksGrid;
end;

procedure TMainForm.btnClearLogClick(Sender: TObject);
begin
  mmoLog.Clear;
end;

procedure TMainForm.btnAddRuntimeLinkClick(Sender: TObject);
var
  L: TBindingLink;
begin
  // Add a new dynamic expression link at runtime!
  L := BindingManager1.AddExpressionLink(tbVolume, 'If(Position > 70, "ALERTA: VOLUME ELEVADO!", "Volume Seguro")',
    lblSubtitle, 'Caption');
  L.Active := True;
  L.Synchronize;

  RefreshLinksGrid;
  LogMessage('Novo vínculo dinâmico criado em tempo de execução: Volume -> Subtitle');
  ShowMessage('Novo vínculo em tempo de execução adicionado com sucesso!'#13#10 +
              'Mova o controle deslizante de volume acima de 70 para ver o subtítulo mudar.');
end;

procedure TMainForm.BindingManager1BeforeSync(Sender: TObject; Link: TBindingLink);
begin
  // Debug / Telemetry hook
end;

procedure TMainForm.BindingManager1AfterSync(Sender: TObject; Link: TBindingLink);
begin
  LogMessage(Format('[Sync OK] %s', [Link.DisplayName]));
end;

procedure TMainForm.BindingManager1BindingError(Sender: TObject; Link: TBindingLink; const ErrorMsg: string);
begin
  LogMessage(Format('[ERRO no Vínculo %s] %s', [Link.DisplayName, ErrorMsg]));
end;

procedure TMainForm.LogMessage(const Msg: string);
begin
  mmoLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), Msg]));
end;

procedure TMainForm.RefreshLinksGrid;
var
  i: Integer;
  L: TBindingLink;
  SrcName, TgtName, ModeStr, ActiveStr: string;
begin
  sgActiveLinks.RowCount := BindingManager1.Links.Count + 1;
  sgActiveLinks.Cells[0, 0] := '#';
  sgActiveLinks.Cells[1, 0] := 'Ativo';
  sgActiveLinks.Cells[2, 0] := 'Origem';
  sgActiveLinks.Cells[3, 0] := 'Propriedade / Expressão';
  sgActiveLinks.Cells[4, 0] := 'Destino';
  sgActiveLinks.Cells[5, 0] := 'Propriedade Alvo';
  sgActiveLinks.Cells[6, 0] := 'Modo';

  for i := 0 to BindingManager1.Links.Count - 1 do
  begin
    L := BindingManager1.Links[i];

    if L.Active then
      ActiveStr := 'SIM'
    else
      ActiveStr := 'NÃO';

    if L.Source <> nil then
      SrcName := L.Source.Name
    else
      SrcName := 'nil';

    if L.Target <> nil then
      TgtName := L.Target.Name
    else
      TgtName := 'nil';

    if L.Mode = bmDirectProperty then
      ModeStr := 'Direto'
    else
      ModeStr := 'Expressão';

    sgActiveLinks.Cells[0, i + 1] := IntToStr(i + 1);
    sgActiveLinks.Cells[1, i + 1] := ActiveStr;
    sgActiveLinks.Cells[2, i + 1] := SrcName;
    if L.Mode = bmDirectProperty then
      sgActiveLinks.Cells[3, i + 1] := L.SourceProperty
    else
      sgActiveLinks.Cells[3, i + 1] := L.SourceExpression;
    sgActiveLinks.Cells[4, i + 1] := TgtName;
    sgActiveLinks.Cells[5, i + 1] := L.TargetProperty;
    sgActiveLinks.Cells[6, i + 1] := ModeStr;
  end;
end;

end.
