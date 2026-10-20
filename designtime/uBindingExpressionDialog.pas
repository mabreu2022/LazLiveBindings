unit uBindingExpressionDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, TypInfo, fpexprpars, uBindingRuntime;

type

  { TBindingExpressionDialog }

  TBindingExpressionDialog = class(TForm)
    pnlTop: TPanel;
    pnlCenter: TPanel;
    pnlBottom: TPanel;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    splitterH: TSplitter;
    gbExpression: TGroupBox;
    mmoExpression: TMemo;
    gbProperties: TGroupBox;
    edtFilterProp: TEdit;
    lbProperties: TListBox;
    gbFunctions: TGroupBox;
    cbCategory: TComboBox;
    lbFunctions: TListBox;
    lblFuncDesc: TLabel;
    pnlTest: TPanel;
    btnTest: TBitBtn;
    lblResult: TLabel;
    pnlButtons: TPanel;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure edtFilterPropChange(Sender: TObject);
    procedure cbCategoryChange(Sender: TObject);
    procedure lbPropertiesDblClick(Sender: TObject);
    procedure lbFunctionsDblClick(Sender: TObject);
    procedure lbFunctionsClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
  private
    FSourceComponent: TComponent;
    FTargetComponent: TComponent;
    FAllProps: TStringList;

    procedure RefreshPropertyList;
    procedure PopulateFunctionsList;
    procedure InsertTextIntoExpression(const AText: string; AOffsetInside: Integer = 0);
    procedure PopulateParserVariables(AParser: TFPExpressionParser);
    function ValidateAndEvaluate(out AResStr: string; out AErrorStr: string): Boolean;
  public
    destructor Destroy; override;
    procedure SetupDialog(ASource, ATarget: TComponent; const AInitialExpr: string);
    function GetExpression: string;
    property Expression: string read GetExpression;
  end;

var
  BindingExpressionDialog: TBindingExpressionDialog;

implementation

{$R *.lfm}

{ TBindingExpressionDialog }

procedure TBindingExpressionDialog.FormCreate(Sender: TObject);
begin
  FAllProps := TStringList.Create;
  cbCategory.ItemIndex := 0;
  PopulateFunctionsList;
end;

destructor TBindingExpressionDialog.Destroy;
begin
  FreeAndNil(FAllProps);
  inherited Destroy;
end;

procedure TBindingExpressionDialog.SetupDialog(ASource, ATarget: TComponent; const AInitialExpr: string);
var
  PropList: PPropList;
  PropInfo: PPropInfo;
  PropCount, i: Integer;
  PName, TypeStr: string;
  OwnerComp, Sibling: TComponent;
  j, SubCount: Integer;
  SubList: PPropList;
  SubInfo: PPropInfo;
begin
  FSourceComponent := ASource;
  FTargetComponent := ATarget;
  mmoExpression.Text := AInitialExpr;
  FAllProps.Clear;

  if FSourceComponent <> nil then
  begin
    PropCount := GetPropList(FSourceComponent.ClassInfo, tkProperties, nil);
    if PropCount > 0 then
    begin
      GetMem(PropList, PropCount * SizeOf(PPropInfo));
      try
        GetPropList(FSourceComponent.ClassInfo, tkProperties, PropList);
        for i := 0 to PropCount - 1 do
        begin
          PropInfo := PropList^[i];
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

          FAllProps.AddObject(Format('%s (%s)', [PName, TypeStr]), TObject(Pointer(IntPtr(1))));
        end;
      finally
        FreeMem(PropList);
      end;
    end;

    // Sibling controls on the same Form
    OwnerComp := FSourceComponent.Owner;
    if OwnerComp <> nil then
    begin
      for j := 0 to OwnerComp.ComponentCount - 1 do
      begin
        Sibling := OwnerComp.Components[j];
        if (Sibling = nil) or (Sibling = FSourceComponent) or (Sibling.Name = '') then
          Continue;

        SubCount := GetPropList(Sibling.ClassInfo, tkProperties, nil);
        if SubCount > 0 then
        begin
          GetMem(SubList, SubCount * SizeOf(PPropInfo));
          try
            GetPropList(Sibling.ClassInfo, tkProperties, SubList);
            for i := 0 to SubCount - 1 do
            begin
              SubInfo := SubList^[i];
              if (SubInfo^.GetProc = nil) then
                Continue;

              case SubInfo^.PropType^.Kind of
                tkInteger: TypeStr := 'Integer';
                tkInt64:   TypeStr := 'Int64';
                tkBool:    TypeStr := 'Boolean';
                tkFloat:   TypeStr := 'Float';
                tkChar, tkSString, tkLString, tkAString, tkWString, tkUString: TypeStr := 'String';
                tkEnumeration: TypeStr := 'Enum';
              else
                TypeStr := 'Outro';
              end;

              FAllProps.AddObject(Format('%s_%s (%s)', [Sibling.Name, SubInfo^.Name, TypeStr]),
                TObject(Pointer(IntPtr(2))));
            end;
          finally
            FreeMem(SubList);
          end;
        end;
      end;
    end;
  end;

  RefreshPropertyList;
  btnTestClick(nil);
end;

procedure TBindingExpressionDialog.RefreshPropertyList;
var
  i: Integer;
  FilterTxt, ItemTxt: string;
begin
  lbProperties.Items.BeginUpdate;
  try
    lbProperties.Clear;
    FilterTxt := UpperCase(Trim(edtFilterProp.Text));
    for i := 0 to FAllProps.Count - 1 do
    begin
      ItemTxt := FAllProps[i];
      if (FilterTxt = '') or (Pos(FilterTxt, UpperCase(ItemTxt)) > 0) then
        lbProperties.Items.Add(ItemTxt);
    end;
  finally
    lbProperties.Items.EndUpdate;
  end;
end;

procedure TBindingExpressionDialog.edtFilterPropChange(Sender: TObject);
begin
  RefreshPropertyList;
end;

procedure TBindingExpressionDialog.PopulateFunctionsList;
var
  Cat: string;
begin
  Cat := cbCategory.Text;
  lbFunctions.Items.BeginUpdate;
  try
    lbFunctions.Clear;

    if (Cat = 'Todas') or (Cat = 'Matemática') then
    begin
      lbFunctions.Items.Add('ABS(X)');
      lbFunctions.Items.Add('ROUND(X)');
      lbFunctions.Items.Add('TRUNC(X)');
      lbFunctions.Items.Add('SQR(X)');
      lbFunctions.Items.Add('SQRT(X)');
      lbFunctions.Items.Add('INT(X)');
      lbFunctions.Items.Add('FRAC(X)');
      lbFunctions.Items.Add('SIN(X)');
      lbFunctions.Items.Add('COS(X)');
      lbFunctions.Items.Add('PI');
    end;

    if (Cat = 'Todas') or (Cat = 'Texto (Strings)') then
    begin
      lbFunctions.Items.Add('UPPER(S)');
      lbFunctions.Items.Add('LOWER(S)');
      lbFunctions.Items.Add('TRIM(S)');
      lbFunctions.Items.Add('LENGTH(S)');
      lbFunctions.Items.Add('COPY(S, Inicio, Qtd)');
      lbFunctions.Items.Add('POS(Substr, S)');
      lbFunctions.Items.Add('STRINGREPLACE(S, Velho, Novo, Flag1, Flag2)');
      lbFunctions.Items.Add('COMPARETEXT(S1, S2)');
    end;

    if (Cat = 'Todas') or (Cat = 'Lógica / Condicional') then
    begin
      lbFunctions.Items.Add('IF(Condicao, "SeVerdade", "SeFalso")');
      lbFunctions.Items.Add('IFNUM(Condicao, ValorVerdade, ValorFalso)');
      lbFunctions.Items.Add('IFS(Condicao, "SeVerdade", "SeFalso")');
      lbFunctions.Items.Add('IFF(Condicao, ValorVerdade, ValorFalso)');
      lbFunctions.Items.Add('IFI(Condicao, IntVerdade, IntFalso)');
    end;

    if (Cat = 'Todas') or (Cat = 'Data e Hora') then
    begin
      lbFunctions.Items.Add('NOW');
      lbFunctions.Items.Add('DATE');
      lbFunctions.Items.Add('TIME');
      lbFunctions.Items.Add('DAYOFWEEK(Data)');
      lbFunctions.Items.Add('EXTRACTYEAR(Data)');
      lbFunctions.Items.Add('EXTRACTMONTH(Data)');
      lbFunctions.Items.Add('EXTRACTDAY(Data)');
      lbFunctions.Items.Add('FORMATDATETIME("dd/mm/yyyy", Data)');
    end;

    if (Cat = 'Todas') or (Cat = 'Conversão') then
    begin
      lbFunctions.Items.Add('INTTOSTR(N)');
      lbFunctions.Items.Add('STRTOINT(S)');
      lbFunctions.Items.Add('FLOATTOSTR(N)');
      lbFunctions.Items.Add('STRTOFLOAT(S)');
      lbFunctions.Items.Add('FORMATFLOAT("#,##0.00", N)');
      lbFunctions.Items.Add('BOOLTOSTR(B)');
      lbFunctions.Items.Add('STRTOBOOL(S)');
    end;

    if (Cat = 'Todas') or (Cat = 'Operadores') then
    begin
      lbFunctions.Items.Add('+');
      lbFunctions.Items.Add('-');
      lbFunctions.Items.Add('*');
      lbFunctions.Items.Add('/');
      lbFunctions.Items.Add('=');
      lbFunctions.Items.Add('<>');
      lbFunctions.Items.Add('>');
      lbFunctions.Items.Add('<');
      lbFunctions.Items.Add('>=');
      lbFunctions.Items.Add('<=');
      lbFunctions.Items.Add('AND');
      lbFunctions.Items.Add('OR');
      lbFunctions.Items.Add('NOT');
    end;
  finally
    lbFunctions.Items.EndUpdate;
  end;
end;

procedure TBindingExpressionDialog.cbCategoryChange(Sender: TObject);
begin
  PopulateFunctionsList;
end;

procedure TBindingExpressionDialog.InsertTextIntoExpression(const AText: string; AOffsetInside: Integer);
var
  SelSt: Integer;
begin
  SelSt := mmoExpression.SelStart;
  mmoExpression.SelText := AText;
  mmoExpression.SetFocus;
  if AOffsetInside > 0 then
    mmoExpression.SelStart := SelSt + AOffsetInside;
end;

procedure TBindingExpressionDialog.lbPropertiesDblClick(Sender: TObject);
var
  Raw, PureName: string;
  P: Integer;
begin
  if lbProperties.ItemIndex < 0 then
    Exit;

  Raw := lbProperties.Items[lbProperties.ItemIndex];
  P := Pos(' (', Raw);
  if P > 0 then
    PureName := Copy(Raw, 1, P - 1)
  else
    PureName := Raw;

  InsertTextIntoExpression(PureName);
end;

procedure TBindingExpressionDialog.lbFunctionsClick(Sender: TObject);
var
  Fn: string;
begin
  if lbFunctions.ItemIndex < 0 then
    Exit;

  Fn := lbFunctions.Items[lbFunctions.ItemIndex];
  if Pos('UPPER', Fn) > 0 then
    lblFuncDesc.Caption := 'UPPER(S): Converte o texto para maiúsculas.'
  else if Pos('LOWER', Fn) > 0 then
    lblFuncDesc.Caption := 'LOWER(S): Converte o texto para minúsculas.'
  else if Pos('TRIM', Fn) > 0 then
    lblFuncDesc.Caption := 'TRIM(S): Remove espaços no início e final.'
  else if Pos('ROUND', Fn) > 0 then
    lblFuncDesc.Caption := 'ROUND(X): Arredonda o número para inteiro.'
  else if Pos('ABS', Fn) > 0 then
    lblFuncDesc.Caption := 'ABS(X): Retorna o valor absoluto positivo.'
  else if Pos('FORMATFLOAT', Fn) > 0 then
    lblFuncDesc.Caption := 'FORMATFLOAT(Mascara, Num): Formata número com máscara (ex: "#,##0.00").'
  else if Pos('IF(', Fn) > 0 then
    lblFuncDesc.Caption := 'IF(Cond, TrueStr, FalseStr): Retorna texto condicional.'
  else
    lblFuncDesc.Caption := Fn;
end;

procedure TBindingExpressionDialog.lbFunctionsDblClick(Sender: TObject);
var
  Fn, InsText: string;
  Offset: Integer;
begin
  if lbFunctions.ItemIndex < 0 then
    Exit;

  Fn := lbFunctions.Items[lbFunctions.ItemIndex];
  if Pos('(', Fn) > 0 then
  begin
    // Insert function name with empty parens and place cursor inside
    InsText := Copy(Fn, 1, Pos('(', Fn)) + ')';
    Offset := Pos('(', Fn);
  end
  else
  begin
    InsText := Fn + ' ';
    Offset := 0;
  end;

  InsertTextIntoExpression(InsText, Offset);
end;

procedure TBindingExpressionDialog.PopulateParserVariables(AParser: TFPExpressionParser);
var
  PropList: PPropList;
  PropInfo: PPropInfo;
  PropCount, i: Integer;
  PName: string;
  OwnerComp, Sibling: TComponent;
  j, SubCount: Integer;
  SubList: PPropList;
  SubInfo: PPropInfo;
  PrefixedName: string;
begin
  if FSourceComponent = nil then
    Exit;

  PropCount := GetPropList(FSourceComponent.ClassInfo, tkProperties, nil);
  if PropCount > 0 then
  begin
    GetMem(PropList, PropCount * SizeOf(PPropInfo));
    try
      GetPropList(FSourceComponent.ClassInfo, tkProperties, PropList);
      for i := 0 to PropCount - 1 do
      begin
        PropInfo := PropList^[i];
        if (PropInfo^.GetProc = nil) then
          Continue;

        PName := PropInfo^.Name;
        case PropInfo^.PropType^.Kind of
          tkInteger, tkInt64:
            AParser.Identifiers.AddIntegerVariable(PName, GetOrdProp(FSourceComponent, PropInfo));
          tkBool:
            AParser.Identifiers.AddBooleanVariable(PName, GetOrdProp(FSourceComponent, PropInfo) <> 0);
          tkFloat:
            AParser.Identifiers.AddFloatVariable(PName, GetFloatProp(FSourceComponent, PropInfo));
          tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
            AParser.Identifiers.AddStringVariable(PName, GetStrProp(FSourceComponent, PropInfo));
          tkEnumeration:
            AParser.Identifiers.AddStringVariable(PName, GetEnumProp(FSourceComponent, PropInfo));
        end;
      end;
    finally
      FreeMem(PropList);
    end;
  end;

  OwnerComp := FSourceComponent.Owner;
  if OwnerComp <> nil then
  begin
    for j := 0 to OwnerComp.ComponentCount - 1 do
    begin
      Sibling := OwnerComp.Components[j];
      if (Sibling = nil) or (Sibling = FSourceComponent) or (Sibling.Name = '') then
        Continue;

      SubCount := GetPropList(Sibling.ClassInfo, tkProperties, nil);
      if SubCount > 0 then
      begin
        GetMem(SubList, SubCount * SizeOf(PPropInfo));
        try
          GetPropList(Sibling.ClassInfo, tkProperties, SubList);
          for i := 0 to SubCount - 1 do
          begin
            SubInfo := SubList^[i];
            if (SubInfo^.GetProc = nil) then
              Continue;

            PrefixedName := Sibling.Name + '_' + SubInfo^.Name;
            case SubInfo^.PropType^.Kind of
              tkInteger, tkInt64:
                AParser.Identifiers.AddIntegerVariable(PrefixedName, GetOrdProp(Sibling, SubInfo));
              tkBool:
                AParser.Identifiers.AddBooleanVariable(PrefixedName, GetOrdProp(Sibling, SubInfo) <> 0);
              tkFloat:
                AParser.Identifiers.AddFloatVariable(PrefixedName, GetFloatProp(Sibling, SubInfo));
              tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
                AParser.Identifiers.AddStringVariable(PrefixedName, GetStrProp(Sibling, SubInfo));
              tkEnumeration:
                AParser.Identifiers.AddStringVariable(PrefixedName, GetEnumProp(Sibling, SubInfo));
            end;
          end;
        finally
          FreeMem(SubList);
        end;
      end;
    end;
  end;
end;

function TBindingExpressionDialog.ValidateAndEvaluate(out AResStr: string; out AErrorStr: string): Boolean;
var
  Parser: TFPExpressionParser;
  Res: TFPExpressionResult;
begin
  AResStr := '';
  AErrorStr := '';
  Result := False;

  if Trim(mmoExpression.Text) = '' then
  begin
    AErrorStr := 'A expressão está vazia.';
    Exit;
  end;

  Parser := TFPExpressionParser.Create(nil);
  try
    RegisterLiveBindingFunctions(Parser);
    PopulateParserVariables(Parser);

    Parser.Expression := mmoExpression.Text;
    Res := Parser.Evaluate;

    case Res.ResultType of
      rtBoolean:  AResStr := Format('[rtBoolean] %s', [BoolToStr(Res.ResBoolean, True)]);
      rtInteger:  AResStr := Format('[rtInteger] %d', [Res.ResInteger]);
      rtFloat:    AResStr := Format('[rtFloat] %g', [Res.ResFloat]);
      rtCurrency: AResStr := Format('[rtCurrency] %m', [Res.ResCurrency]);
      rtDateTime: AResStr := Format('[rtDateTime] %s', [DateTimeToStr(Res.ResDateTime)]);
      rtString:   AResStr := Format('[rtString] "%s"', [Res.ResString]);
    end;

    Result := True;
  except
    on E: Exception do
    begin
      AErrorStr := E.Message;
      Result := False;
    end;
  end;
  Parser.Free;
end;

procedure TBindingExpressionDialog.btnTestClick(Sender: TObject);
var
  ResVal, ErrVal: string;
begin
  if Trim(mmoExpression.Text) = '' then
  begin
    lblResult.Font.Color := clGray;
    lblResult.Caption := 'Digite uma expressão e clique em Testar Expressão.';
    Exit;
  end;

  if ValidateAndEvaluate(ResVal, ErrVal) then
  begin
    lblResult.Font.Color := clGreen;
    lblResult.Caption := '✓ Válida! ' + ResVal;
  end
  else
  begin
    lblResult.Font.Color := clRed;
    lblResult.Caption := '✗ Erro: ' + ErrVal;
  end;
end;

function TBindingExpressionDialog.GetExpression: string;
begin
  Result := Trim(mmoExpression.Text);
end;

end.
