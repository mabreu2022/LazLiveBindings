unit uBindingRuntime;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TypInfo, Rtti, fpexprpars;

type
  TBindingDirection = (bdSourceToTarget, bdTargetToSource, bdTwoWay);
  TBindingMode = (bmDirectProperty, bmExpression);

  TBindingManager = class;
  TBindingLink = class;

  TBindingErrorEvent = procedure(Sender: TObject; Link: TBindingLink; const ErrorMsg: string) of object;
  TBindingNotifyEvent = procedure(Sender: TObject; Link: TBindingLink) of object;

  { TBindingLink }

  TBindingLink = class(TCollectionItem)
  private
    FSource: TComponent;
    FSourceProperty: string;
    FSourceExpression: string;
    FTarget: TComponent;
    FTargetProperty: string;
    FDirection: TBindingDirection;
    FMode: TBindingMode;
    FActive: Boolean;
    FFormatMask: string;
    FSynchronizing: Boolean;
    FLastError: string;

    procedure SetSource(const AValue: TComponent);
    procedure SetTarget(const AValue: TComponent);
    procedure SetSourceProperty(const AValue: string);
    procedure SetSourceExpression(const AValue: string);
    procedure SetTargetProperty(const AValue: string);
    procedure SetDirection(const AValue: TBindingDirection);
    procedure SetMode(const AValue: TBindingMode);
    procedure SetActive(const AValue: Boolean);
    procedure SetFormatMask(const AValue: string);

    function GetOwnerManager: TBindingManager;
    procedure PopulateParserVariables(AParser: TFPExpressionParser);
    function ConvertExprResultToTarget(const ARes: TFPExpressionResult; ATargetPropInfo: PPropInfo): TValue;
  protected
    function GetDisplayName: string; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); virtual;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;

    procedure Synchronize;
    procedure SynchronizeSourceToTarget;
    procedure SynchronizeTargetToSource;

    property OwnerManager: TBindingManager read GetOwnerManager;
    property LastError: string read FLastError;
    property IsSynchronizing: Boolean read FSynchronizing;
  published
    property Source: TComponent read FSource write SetSource;
    property SourceProperty: string read FSourceProperty write SetSourceProperty;
    property SourceExpression: string read FSourceExpression write SetSourceExpression;
    property Target: TComponent read FTarget write SetTarget;
    property TargetProperty: string read FTargetProperty write SetTargetProperty;
    property Direction: TBindingDirection read FDirection write SetDirection default bdSourceToTarget;
    property Mode: TBindingMode read FMode write SetMode default bmDirectProperty;
    property Active: Boolean read FActive write SetActive default True;
    property FormatMask: string read FFormatMask write SetFormatMask;
  end;

  { TBindingLinks }

  TBindingLinks = class(TCollection)
  private
    FOwnerManager: TBindingManager;
    function GetItem(Index: Integer): TBindingLink;
    procedure SetItem(Index: Integer; Value: TBindingLink);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TBindingManager);
    function Add: TBindingLink;
    function Insert(Index: Integer): TBindingLink;
    procedure SynchronizeAll;

    property Items[Index: Integer]: TBindingLink read GetItem write SetItem; default;
    property OwnerManager: TBindingManager read FOwnerManager;
  end;

  { TBindingManager }

  TBindingManager = class(TComponent)
  private
    FLinks: TBindingLinks;
    FAutoSyncOnLoaded: Boolean;
    FActive: Boolean;
    FOnBindingError: TBindingErrorEvent;
    FOnBeforeSync: TBindingNotifyEvent;
    FOnAfterSync: TBindingNotifyEvent;

    procedure SetLinks(AValue: TBindingLinks);
    procedure SetActive(AValue: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SynchronizeAll;
    procedure SynchronizeSource(ASource: TComponent);
    procedure SynchronizeTarget(ATarget: TComponent);
    procedure SynchronizeLink(ALink: TBindingLink);

    function AddLink(ASource: TComponent; const ASourceProp: string;
      ATarget: TComponent; const ATargetProp: string): TBindingLink;
    function AddExpressionLink(ASource: TComponent; const AExpr: string;
      ATarget: TComponent; const ATargetProp: string): TBindingLink;
    procedure RemoveLink(ALink: TBindingLink);
    procedure ClearLinks;
  published
    property Links: TBindingLinks read FLinks write SetLinks;
    property AutoSyncOnLoaded: Boolean read FAutoSyncOnLoaded write FAutoSyncOnLoaded default True;
    property Active: Boolean read FActive write SetActive default True;
    property OnBindingError: TBindingErrorEvent read FOnBindingError write FOnBindingError;
    property OnBeforeSync: TBindingNotifyEvent read FOnBeforeSync write FOnBeforeSync;
    property OnAfterSync: TBindingNotifyEvent read FOnAfterSync write FOnAfterSync;
  end;

{ Helper RTTI conversion routines }
function RttiGetPropertyValue(AObject: TObject; const APropName: string; out AValue: TValue): Boolean;
function RttiSetPropertyValue(AObject: TObject; const APropName: string; const AValue: TValue): Boolean;
function ConvertTValueToPropType(const ASourceVal: TValue; ATargetPropInfo: PPropInfo): TValue;
procedure RegisterLiveBindingFunctions(AParser: TFPExpressionParser);

implementation

{ Custom Expression Callbacks for fpexprpars }

procedure ExprFuncUpper(var Result: TFPExpressionResult; const Args: TExprParameterArray);
begin
  Result.ResultType := rtString;
  Result.ResString := UpperCase(Args[0].ResString);
end;

procedure ExprFuncLower(var Result: TFPExpressionResult; const Args: TExprParameterArray);
begin
  Result.ResultType := rtString;
  Result.ResString := LowerCase(Args[0].ResString);
end;

procedure ExprFuncTrim(var Result: TFPExpressionResult; const Args: TExprParameterArray);
begin
  Result.ResultType := rtString;
  Result.ResString := Trim(Args[0].ResString);
end;

procedure ExprFuncIf(var Result: TFPExpressionResult; const Args: TExprParameterArray);
begin
  Result.ResultType := rtString;
  if Args[0].ResBoolean then
    Result.ResString := Args[1].ResString
  else
    Result.ResString := Args[2].ResString;
end;

procedure ExprFuncIfNum(var Result: TFPExpressionResult; const Args: TExprParameterArray);
begin
  Result.ResultType := rtFloat;
  if Args[0].ResBoolean then
    Result.ResFloat := Args[1].ResFloat
  else
    Result.ResFloat := Args[2].ResFloat;
end;

procedure RegisterLiveBindingFunctions(AParser: TFPExpressionParser);
begin
  if AParser = nil then
    Exit;
  AParser.BuiltIns := [bcStrings, bcDateTime, bcMath, bcBoolean, bcConversion];
  AParser.Identifiers.AddFunction('upper', 'S', 'S', @ExprFuncUpper);
  AParser.Identifiers.AddFunction('lower', 'S', 'S', @ExprFuncLower);
  AParser.Identifiers.AddFunction('trim', 'S', 'S', @ExprFuncTrim);
  AParser.Identifiers.AddFunction('if', 'S', 'BSS', @ExprFuncIf);
  AParser.Identifiers.AddFunction('ifnum', 'F', 'BFF', @ExprFuncIfNum);
end;

{ Helper RTTI conversion routines }

function RttiGetPropertyValue(AObject: TObject; const APropName: string; out AValue: TValue): Boolean;
var
  PropInfo: PPropInfo;
begin
  Result := False;
  AValue := TValue.Empty;
  if (AObject = nil) or (APropName = '') then
    Exit;

  PropInfo := GetPropInfo(AObject.ClassInfo, APropName);
  if (PropInfo = nil) or (PropInfo^.GetProc = nil) then
    Exit;

  case PropInfo^.PropType^.Kind of
    tkInteger:
      AValue := GetOrdProp(AObject, PropInfo);
    tkInt64:
      AValue := GetInt64Prop(AObject, PropInfo);
    tkBool:
      AValue := (GetOrdProp(AObject, PropInfo) <> 0);
    tkFloat:
      AValue := GetFloatProp(AObject, PropInfo);
    tkChar, tkSString, tkLString, tkAString:
      AValue := GetStrProp(AObject, PropInfo);
    tkWString, tkUString:
      AValue := GetUnicodeStrProp(AObject, PropInfo);
    tkEnumeration:
      AValue := GetEnumProp(AObject, PropInfo);
    tkSet:
      AValue := GetSetProp(AObject, PropInfo, True);
    tkClass:
      AValue := GetObjectProp(AObject, PropInfo);
  else
    Exit;
  end;
  Result := True;
end;

function ConvertTValueToPropType(const ASourceVal: TValue; ATargetPropInfo: PPropInfo): TValue;
var
  TargetKind: TTypeKind;
  StrVal: string;
  DblVal: Double;
  IntVal: Int64;
  BoolVal: Boolean;
begin
  Result := ASourceVal;
  if (ATargetPropInfo = nil) or ASourceVal.IsEmpty then
    Exit;

  TargetKind := ATargetPropInfo^.PropType^.Kind;

  // Extract source representations
  case ASourceVal.Kind of
    tkInteger, tkInt64:
      begin
        IntVal := ASourceVal.AsInt64;
        DblVal := IntVal;
        StrVal := IntToStr(IntVal);
        BoolVal := (IntVal <> 0);
      end;
    tkFloat:
      begin
        DblVal := ASourceVal.AsExtended;
        IntVal := Round(DblVal);
        StrVal := FloatToStr(DblVal);
        BoolVal := (DblVal <> 0.0);
      end;
    tkBool:
      begin
        BoolVal := ASourceVal.AsBoolean;
        if BoolVal then
        begin
          IntVal := 1;
          DblVal := 1.0;
          StrVal := 'True';
        end
        else
        begin
          IntVal := 0;
          DblVal := 0.0;
          StrVal := 'False';
        end;
      end;
    tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
      begin
        StrVal := ASourceVal.AsString;
        IntVal := StrToInt64Def(Trim(StrVal), 0);
        DblVal := StrToFloatDef(Trim(StrVal), 0.0);
        BoolVal := SameText(Trim(StrVal), 'True') or (IntVal <> 0);
      end;
  else
    StrVal := ASourceVal.ToString;
    IntVal := StrToInt64Def(Trim(StrVal), 0);
    DblVal := StrToFloatDef(Trim(StrVal), 0.0);
    BoolVal := (IntVal <> 0);
  end;

  // Convert to expected target kind
  case TargetKind of
    tkInteger:
      Result := Integer(IntVal);
    tkInt64:
      Result := IntVal;
    tkBool:
      Result := BoolVal;
    tkFloat:
      Result := DblVal;
    tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
      Result := StrVal;
    tkEnumeration:
      begin
        // If target is an enum, try to find ordinal by name or use numeric value
        if StrVal <> '' then
          Result := TValue.FromOrdinal(ATargetPropInfo^.PropType, GetEnumValue(ATargetPropInfo^.PropType, StrVal))
        else
          Result := TValue.FromOrdinal(ATargetPropInfo^.PropType, IntVal);
      end;
  end;
end;

function RttiSetPropertyValue(AObject: TObject; const APropName: string; const AValue: TValue): Boolean;
var
  PropInfo: PPropInfo;
  ConvertedVal: TValue;
begin
  Result := False;
  if (AObject = nil) or (APropName = '') then
    Exit;

  PropInfo := GetPropInfo(AObject.ClassInfo, APropName);
  if (PropInfo = nil) or (PropInfo^.SetProc = nil) then
    Exit;

  ConvertedVal := ConvertTValueToPropType(AValue, PropInfo);

  try
    case PropInfo^.PropType^.Kind of
      tkInteger:
        SetOrdProp(AObject, PropInfo, ConvertedVal.AsInteger);
      tkInt64:
        SetInt64Prop(AObject, PropInfo, ConvertedVal.AsInt64);
      tkBool:
        SetOrdProp(AObject, PropInfo, Ord(ConvertedVal.AsBoolean));
      tkFloat:
        SetFloatProp(AObject, PropInfo, ConvertedVal.AsExtended);
      tkChar, tkSString, tkLString, tkAString:
        SetStrProp(AObject, PropInfo, ConvertedVal.AsString);
      tkWString, tkUString:
        SetUnicodeStrProp(AObject, PropInfo, ConvertedVal.AsString);
      tkEnumeration:
        begin
          if ConvertedVal.Kind in [tkChar, tkSString, tkLString, tkAString, tkWString, tkUString] then
            SetEnumProp(AObject, PropInfo, ConvertedVal.AsString)
          else
            SetOrdProp(AObject, PropInfo, ConvertedVal.AsOrdinal);
        end;
      tkSet:
        SetSetProp(AObject, PropInfo, ConvertedVal.AsString);
      tkClass:
        SetObjectProp(AObject, PropInfo, ConvertedVal.AsObject);
    else
      Exit;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

{ TBindingLink }

constructor TBindingLink.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FDirection := bdSourceToTarget;
  FMode := bmDirectProperty;
  FActive := True;
  FSynchronizing := False;
  FLastError := '';
  FFormatMask := '';
end;

destructor TBindingLink.Destroy;
begin
  inherited Destroy;
end;

procedure TBindingLink.Assign(ASource: TPersistent);
var
  SrcLink: TBindingLink;
begin
  if ASource is TBindingLink then
  begin
    SrcLink := TBindingLink(ASource);
    FSource := SrcLink.Source;
    FSourceProperty := SrcLink.SourceProperty;
    FSourceExpression := SrcLink.SourceExpression;
    FTarget := SrcLink.Target;
    FTargetProperty := SrcLink.TargetProperty;
    FDirection := SrcLink.Direction;
    FMode := SrcLink.Mode;
    FActive := SrcLink.Active;
    FFormatMask := SrcLink.FormatMask;
  end
  else
    inherited Assign(ASource);
end;

function TBindingLink.GetDisplayName: string;
var
  SrcName, TgtName: string;
begin
  if Assigned(FSource) then
    SrcName := FSource.Name
  else
    SrcName := '(sem origem)';

  if Assigned(FTarget) then
    TgtName := FTarget.Name
  else
    TgtName := '(sem destino)';

  if FMode = bmDirectProperty then
    Result := Format('%s.%s -> %s.%s', [SrcName, FSourceProperty, TgtName, FTargetProperty])
  else
    Result := Format('"%s" -> %s.%s', [FSourceExpression, TgtName, FTargetProperty]);
end;

function TBindingLink.GetOwnerManager: TBindingManager;
begin
  if Collection is TBindingLinks then
    Result := TBindingLinks(Collection).OwnerManager
  else
    Result := nil;
end;

procedure TBindingLink.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if Operation = opRemove then
  begin
    if FSource = AComponent then
      FSource := nil;
    if FTarget = AComponent then
      FTarget := nil;
  end;
end;

procedure TBindingLink.SetSource(const AValue: TComponent);
begin
  if FSource <> AValue then
  begin
    FSource := AValue;
    if Assigned(FSource) and Assigned(OwnerManager) then
      FSource.FreeNotification(OwnerManager);
  end;
end;

procedure TBindingLink.SetTarget(const AValue: TComponent);
begin
  if FTarget <> AValue then
  begin
    FTarget := AValue;
    if Assigned(FTarget) and Assigned(OwnerManager) then
      FTarget.FreeNotification(OwnerManager);
  end;
end;

procedure TBindingLink.SetSourceProperty(const AValue: string);
begin
  if FSourceProperty <> AValue then
    FSourceProperty := Trim(AValue);
end;

procedure TBindingLink.SetSourceExpression(const AValue: string);
begin
  if FSourceExpression <> AValue then
    FSourceExpression := Trim(AValue);
end;

procedure TBindingLink.SetTargetProperty(const AValue: string);
begin
  if FTargetProperty <> AValue then
    FTargetProperty := Trim(AValue);
end;

procedure TBindingLink.SetDirection(const AValue: TBindingDirection);
begin
  FDirection := AValue;
end;

procedure TBindingLink.SetMode(const AValue: TBindingMode);
begin
  FMode := AValue;
end;

procedure TBindingLink.SetActive(const AValue: Boolean);
begin
  if FActive <> AValue then
  begin
    FActive := AValue;
    if FActive and not (csDesigning in OwnerManager.ComponentState) then
      Synchronize;
  end;
end;

procedure TBindingLink.SetFormatMask(const AValue: string);
begin
  FFormatMask := Trim(AValue);
end;

procedure TBindingLink.PopulateParserVariables(AParser: TFPExpressionParser);
var
  PropList: PPropList;
  PropInfo: PPropInfo;
  PropCount, i: Integer;
  PName: string;
  OwnerComp: TComponent;
  Sibling: TComponent;
  j, SubPropCount: Integer;
  SubPropList: PPropList;
  SubPropInfo: PPropInfo;
  PrefixedName: string;
begin
  if FSource = nil then
    Exit;

  // 1. Register Source's own published properties
  PropCount := GetPropList(FSource.ClassInfo, tkProperties, nil);
  if PropCount > 0 then
  begin
    GetMem(PropList, PropCount * SizeOf(PPropInfo));
    try
      GetPropList(FSource.ClassInfo, tkProperties, PropList);
      for i := 0 to PropCount - 1 do
      begin
        PropInfo := PropList^[i];
        if (PropInfo^.GetProc = nil) then
          Continue;

        PName := PropInfo^.Name;
        case PropInfo^.PropType^.Kind of
          tkInteger, tkInt64:
            AParser.Identifiers.AddIntegerVariable(PName, GetOrdProp(FSource, PropInfo));
          tkBool:
            AParser.Identifiers.AddBooleanVariable(PName, GetOrdProp(FSource, PropInfo) <> 0);
          tkFloat:
            AParser.Identifiers.AddFloatVariable(PName, GetFloatProp(FSource, PropInfo));
          tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
            AParser.Identifiers.AddStringVariable(PName, GetStrProp(FSource, PropInfo));
          tkEnumeration:
            AParser.Identifiers.AddStringVariable(PName, GetEnumProp(FSource, PropInfo));
        end;
      end;
    finally
      FreeMem(PropList);
    end;
  end;

  // 2. Register sibling components on the same Owner form (e.g. Edit1_Text, SpinEdit1_Value)
  OwnerComp := FSource.Owner;
  if OwnerComp <> nil then
  begin
    for j := 0 to OwnerComp.ComponentCount - 1 do
    begin
      Sibling := OwnerComp.Components[j];
      if (Sibling = nil) or (Sibling = FSource) or (Sibling.Name = '') then
        Continue;

      SubPropCount := GetPropList(Sibling.ClassInfo, tkProperties, nil);
      if SubPropCount > 0 then
      begin
        GetMem(SubPropList, SubPropCount * SizeOf(PPropInfo));
        try
          GetPropList(Sibling.ClassInfo, tkProperties, SubPropList);
          for i := 0 to SubPropCount - 1 do
          begin
            SubPropInfo := SubPropList^[i];
            if (SubPropInfo^.GetProc = nil) then
              Continue;

            PrefixedName := Sibling.Name + '_' + SubPropInfo^.Name;
            case SubPropInfo^.PropType^.Kind of
              tkInteger, tkInt64:
                AParser.Identifiers.AddIntegerVariable(PrefixedName, GetOrdProp(Sibling, SubPropInfo));
              tkBool:
                AParser.Identifiers.AddBooleanVariable(PrefixedName, GetOrdProp(Sibling, SubPropInfo) <> 0);
              tkFloat:
                AParser.Identifiers.AddFloatVariable(PrefixedName, GetFloatProp(Sibling, SubPropInfo));
              tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
                AParser.Identifiers.AddStringVariable(PrefixedName, GetStrProp(Sibling, SubPropInfo));
              tkEnumeration:
                AParser.Identifiers.AddStringVariable(PrefixedName, GetEnumProp(Sibling, SubPropInfo));
            end;
          end;
        finally
          FreeMem(SubPropList);
        end;
      end;
    end;
  end;
end;

function TBindingLink.ConvertExprResultToTarget(const ARes: TFPExpressionResult; ATargetPropInfo: PPropInfo): TValue;
var
  TargetKind: TTypeKind;
  StrVal: string;
begin
  Result := TValue.Empty;
  if ATargetPropInfo = nil then
    Exit;

  TargetKind := ATargetPropInfo^.PropType^.Kind;

  case TargetKind of
    tkChar, tkSString, tkLString, tkAString, tkWString, tkUString:
      begin
        case ARes.ResultType of
          rtString:   StrVal := ARes.ResString;
          rtInteger:  StrVal := IntToStr(ARes.ResInteger);
          rtFloat:    StrVal := FloatToStr(ARes.ResFloat);
          rtCurrency: StrVal := CurrToStr(ARes.ResCurrency);
          rtBoolean:  StrVal := BoolToStr(ARes.ResBoolean, True);
          rtDateTime: StrVal := DateTimeToStr(ARes.ResDateTime);
        end;

        // Apply format mask if specified
        if FFormatMask <> '' then
        begin
          try
            case ARes.ResultType of
              rtFloat, rtCurrency:
                StrVal := FormatFloat(FFormatMask, ARes.ResFloat);
              rtInteger:
                StrVal := Format(FFormatMask, [ARes.ResInteger]);
              rtDateTime:
                StrVal := FormatDateTime(FFormatMask, ARes.ResDateTime);
              rtString:
                StrVal := Format(FFormatMask, [ARes.ResString]);
            end;
          except
            // keep raw StrVal if mask fails
          end;
        end;

        Result := StrVal;
      end;

    tkInteger:
      begin
        case ARes.ResultType of
          rtInteger:  Result := Integer(ARes.ResInteger);
          rtFloat:    Result := Integer(Round(ARes.ResFloat));
          rtCurrency: Result := Integer(Round(ARes.ResCurrency));
          rtBoolean:  Result := Integer(Ord(ARes.ResBoolean));
          rtString:   Result := StrToIntDef(Trim(ARes.ResString), 0);
        else
          Result := 0;
        end;
      end;

    tkInt64:
      begin
        case ARes.ResultType of
          rtInteger:  Result := ARes.ResInteger;
          rtFloat:    Result := Round(ARes.ResFloat);
          rtCurrency: Result := Round(ARes.ResCurrency);
          rtBoolean:  Result := Int64(Ord(ARes.ResBoolean));
          rtString:   Result := StrToInt64Def(Trim(ARes.ResString), 0);
        else
          Result := Int64(0);
        end;
      end;

    tkFloat:
      begin
        case ARes.ResultType of
          rtFloat:    Result := Double(ARes.ResFloat);
          rtInteger:  Result := Double(ARes.ResInteger);
          rtCurrency: Result := Double(ARes.ResCurrency);
          rtString:   Result := StrToFloatDef(Trim(ARes.ResString), 0.0);
        else
          Result := 0.0;
        end;
      end;

    tkBool:
      begin
        case ARes.ResultType of
          rtBoolean:  Result := ARes.ResBoolean;
          rtInteger:  Result := (ARes.ResInteger <> 0);
          rtFloat:    Result := (ARes.ResFloat <> 0.0);
          rtString:   Result := StrToBoolDef(Trim(ARes.ResString), False);
        else
          Result := False;
        end;
      end;

    tkEnumeration:
      begin
        case ARes.ResultType of
          rtInteger:
            Result := TValue.FromOrdinal(ATargetPropInfo^.PropType, ARes.ResInteger);
          rtString:
            Result := TValue.FromOrdinal(ATargetPropInfo^.PropType, GetEnumValue(ATargetPropInfo^.PropType, Trim(ARes.ResString)));
        else
          Result := TValue.FromOrdinal(ATargetPropInfo^.PropType, 0);
        end;
      end;
  end;
end;

procedure TBindingLink.SynchronizeSourceToTarget;
var
  Val: TValue;
  Parser: TFPExpressionParser;
  ExprRes: TFPExpressionResult;
  TgtPropInfo: PPropInfo;
  FmtStr: string;
begin
  if FTarget = nil then
    Exit;

  TgtPropInfo := GetPropInfo(FTarget.ClassInfo, FTargetProperty);
  if TgtPropInfo = nil then
    Exit;

  if FMode = bmDirectProperty then
  begin
    if (FSource = nil) or (FSourceProperty = '') then
      Exit;

    if RttiGetPropertyValue(FSource, FSourceProperty, Val) then
    begin
      // Apply format mask if target is a string and mask exists
      if (FFormatMask <> '') and (TgtPropInfo^.PropType^.Kind in [tkChar, tkSString, tkLString, tkAString, tkWString, tkUString]) then
      begin
        try
          case Val.Kind of
            tkFloat:
              begin
                FmtStr := FormatFloat(FFormatMask, Val.AsExtended);
                Val := FmtStr;
              end;
            tkInteger, tkInt64:
              begin
                FmtStr := Format(FFormatMask, [Val.AsInt64]);
                Val := FmtStr;
              end;
          end;
        except
          // ignore mask errors
        end;
      end;

      RttiSetPropertyValue(FTarget, FTargetProperty, Val);
    end;
  end
  else if FMode = bmExpression then
  begin
    if Trim(FSourceExpression) = '' then
      Exit;

    Parser := TFPExpressionParser.Create(nil);
    try
      RegisterLiveBindingFunctions(Parser);

      // Populate Source properties and sibling controls
      PopulateParserVariables(Parser);

      Parser.Expression := FSourceExpression;
      ExprRes := Parser.Evaluate;

      Val := ConvertExprResultToTarget(ExprRes, TgtPropInfo);
      if not Val.IsEmpty then
        RttiSetPropertyValue(FTarget, FTargetProperty, Val);

      FLastError := '';
    finally
      Parser.Free;
    end;
  end;
end;

procedure TBindingLink.SynchronizeTargetToSource;
var
  Val: TValue;
begin
  // Target to Source is only supported for direct property bindings
  if (FMode <> bmDirectProperty) or (FSource = nil) or (FTarget = nil) then
    Exit;

  if (FSourceProperty = '') or (FTargetProperty = '') then
    Exit;

  if RttiGetPropertyValue(FTarget, FTargetProperty, Val) then
    RttiSetPropertyValue(FSource, FSourceProperty, Val);
end;

procedure TBindingLink.Synchronize;
var
  Mgr: TBindingManager;
begin
  if not FActive or FSynchronizing then
    Exit;

  Mgr := OwnerManager;
  if Assigned(Mgr) and not Mgr.Active then
    Exit;

  FSynchronizing := True;
  try
    FLastError := '';
    if Assigned(Mgr) and Assigned(Mgr.OnBeforeSync) then
      Mgr.OnBeforeSync(Mgr, Self);

    case FDirection of
      bdSourceToTarget:
        SynchronizeSourceToTarget;
      bdTargetToSource:
        SynchronizeTargetToSource;
      bdTwoWay:
        begin
          // By default, synchronize source to target
          SynchronizeSourceToTarget;
        end;
    end;

    if Assigned(Mgr) and Assigned(Mgr.OnAfterSync) then
      Mgr.OnAfterSync(Mgr, Self);
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      if Assigned(Mgr) and Assigned(Mgr.OnBindingError) then
        Mgr.OnBindingError(Mgr, Self, E.Message);
    end;
  end;
  FSynchronizing := False;
end;

{ TBindingLinks }

constructor TBindingLinks.Create(AOwner: TBindingManager);
begin
  inherited Create(TBindingLink);
  FOwnerManager := AOwner;
end;

function TBindingLinks.GetOwner: TPersistent;
begin
  Result := FOwnerManager;
end;

function TBindingLinks.GetItem(Index: Integer): TBindingLink;
begin
  Result := TBindingLink(inherited GetItem(Index));
end;

procedure TBindingLinks.SetItem(Index: Integer; Value: TBindingLink);
begin
  inherited SetItem(Index, Value);
end;

function TBindingLinks.Add: TBindingLink;
begin
  Result := TBindingLink(inherited Add);
end;

function TBindingLinks.Insert(Index: Integer): TBindingLink;
begin
  Result := TBindingLink(inherited Insert(Index));
end;

procedure TBindingLinks.SynchronizeAll;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    Items[i].Synchronize;
end;

{ TBindingManager }

constructor TBindingManager.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLinks := TBindingLinks.Create(Self);
  FAutoSyncOnLoaded := True;
  FActive := True;
end;

destructor TBindingManager.Destroy;
begin
  FreeAndNil(FLinks);
  inherited Destroy;
end;

procedure TBindingManager.SetLinks(AValue: TBindingLinks);
begin
  FLinks.Assign(AValue);
end;

procedure TBindingManager.SetActive(AValue: Boolean);
begin
  if FActive <> AValue then
  begin
    FActive := AValue;
    if FActive and not (csDesigning in ComponentState) then
      SynchronizeAll;
  end;
end;

procedure TBindingManager.Notification(AComponent: TComponent; Operation: TOperation);
var
  i: Integer;
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and Assigned(FLinks) then
  begin
    for i := 0 to FLinks.Count - 1 do
      FLinks[i].Notification(AComponent, Operation);
  end;
end;

procedure TBindingManager.Loaded;
begin
  inherited Loaded;
  if FAutoSyncOnLoaded and FActive and not (csDesigning in ComponentState) then
    SynchronizeAll;
end;

procedure TBindingManager.SynchronizeAll;
begin
  if FActive and Assigned(FLinks) then
    FLinks.SynchronizeAll;
end;

procedure TBindingManager.SynchronizeSource(ASource: TComponent);
var
  i: Integer;
begin
  if not FActive or (FLinks = nil) or (ASource = nil) then
    Exit;

  for i := 0 to FLinks.Count - 1 do
  begin
    if FLinks[i].Source = ASource then
      FLinks[i].Synchronize;
  end;
end;

procedure TBindingManager.SynchronizeTarget(ATarget: TComponent);
var
  i: Integer;
begin
  if not FActive or (FLinks = nil) or (ATarget = nil) then
    Exit;

  for i := 0 to FLinks.Count - 1 do
  begin
    if FLinks[i].Target = ATarget then
      FLinks[i].Synchronize;
  end;
end;

procedure TBindingManager.SynchronizeLink(ALink: TBindingLink);
begin
  if FActive and (ALink <> nil) then
    ALink.Synchronize;
end;

function TBindingManager.AddLink(ASource: TComponent; const ASourceProp: string;
  ATarget: TComponent; const ATargetProp: string): TBindingLink;
begin
  Result := FLinks.Add;
  Result.Mode := bmDirectProperty;
  Result.Source := ASource;
  Result.SourceProperty := ASourceProp;
  Result.Target := ATarget;
  Result.TargetProperty := ATargetProp;
  Result.Active := True;
end;

function TBindingManager.AddExpressionLink(ASource: TComponent; const AExpr: string;
  ATarget: TComponent; const ATargetProp: string): TBindingLink;
begin
  Result := FLinks.Add;
  Result.Mode := bmExpression;
  Result.Source := ASource;
  Result.SourceExpression := AExpr;
  Result.Target := ATarget;
  Result.TargetProperty := ATargetProp;
  Result.Active := True;
end;

procedure TBindingManager.RemoveLink(ALink: TBindingLink);
var
  idx: Integer;
begin
  if (FLinks <> nil) and (ALink <> nil) then
  begin
    idx := ALink.Index;
    if (idx >= 0) and (idx < FLinks.Count) then
      FLinks.Delete(idx);
  end;
end;

procedure TBindingManager.ClearLinks;
begin
  if FLinks <> nil then
    FLinks.Clear;
end;

end.
