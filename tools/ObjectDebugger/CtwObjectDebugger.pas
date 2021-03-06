unit CtwObjectDebugger;

(**************************************************************

      Cantools Object Debugger
      Instructions on Appendix A, Mastering Delphi 7

      Released under LGPL license, distribute but keep this
      copyright notice. Please forward bug fixes and modifications
      to the author

      Copyright 1998-2003 Marco Cant�, www.marcocantu.com

**************************************************************)

// usage information: install and drop component or create one at 
// runtime as in the companion demo


interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, TypInfo, ExtCtrls, Grids,
  Buttons, Menus, ComCtrls;

////// component //////

type
  TCantObjectDebugger = class(TComponent)
  private
    fOnTop: Boolean;
    fCopyright, fNull: string;
  public
    constructor Create (AOwner: TComponent); override;
  published
    property OnTop: Boolean
      read fOnTop write fOnTop;
    property Copyright: string
      read fCopyright write fNull;
  end;

procedure Register;

////// form //////

type
  TCantObjDebForm = class(TForm)
    ColorDialog1: TColorDialog;
    FontDialog1: TFontDialog;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    sgProp: TStringGrid;
    Panel1: TPanel;
    cbComps: TComboBox;
    MainMenu1: TMainMenu;
    cbForms: TComboBox;
    sgEvt: TStringGrid;
    Options1: TMenuItem;
    RefreshForms1: TMenuItem;
    RefreshComponents1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    RefreshValues1: TMenuItem;
    ComboColor: TComboBox;
    ComboCursor: TComboBox;
    ComboEnum: TComboBox;
    EditNum: TEdit;
    EditStr: TEdit;
    N1: TMenuItem;
    TopMost1: TMenuItem;
    EditCh: TEdit;
    ListSet: TListBox;
    Info1: TMenuItem;
    Timer1: TTimer;
    TabSheet3: TTabSheet;
    sgData: TStringGrid;
    procedure cbFormsChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure cbCompsChange(Sender: TObject);
    procedure sgPropSelectCell(Sender: TObject; Col, Row: Longint;
      var CanSelect: Boolean);
    procedure RefreshForms1Click(Sender: TObject);
    procedure RefreshComponents1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure RefreshValues1Click(Sender: TObject);
    procedure sgDataSelectCell(Sender: TObject; Col, Row: Longint;
      var CanSelect: Boolean);
    procedure sgMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure EditStrExit(Sender: TObject);
    procedure EditNumExit(Sender: TObject);
    procedure ComboColorDblClick(Sender: TObject);
    procedure ComboColorChange(Sender: TObject);
    procedure ComboCursorChange(Sender: TObject);
    procedure ComboEnumChange(Sender: TObject);
    procedure EditNumKeyPress(Sender: TObject; var Key: Char);
    procedure ComboEnumDblClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TopMost1Click(Sender: TObject);
    procedure EditChExit(Sender: TObject);
    procedure ListSetClick(Sender: TObject);
    procedure RefreshOnExit(Sender: TObject);
    procedure sgPropDblClick(Sender: TObject);
    procedure Info1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure EditChange(Sender: TObject);
  private
    // the current component
    CurrComp: TComponent;
    // the real component (if a subproperty is active)
    RealComp: TComponent;
    // are we editing a subproperty?
    EditingSub: Boolean;
    // current form: TForm or TDataModule
    CurrForm: TComponent;
    // current property
    CurrProp: PPropInfo;
    // current row in grid
    CurrRow: Integer;
    // combo box used by AddToCombo method
    Combo: TComboBox;
    // edit box has been modified?
    EditModified: Boolean;
  public
    procedure UpdateFormsCombo;
    procedure UpdateCompsCombo;
    procedure UpdateProps;
    procedure UpdateData;
    procedure EditStringList (Str: TStrings);
    procedure AddToCombo (const S: String);
  end;

var
  CantObjDebForm: TCantObjDebForm;

implementation

{$R *.DFM}

const
  VersionDescription = 'Object Debugger for Delphi 4 (Rel. 01)';
  VersionRelease = 'Release 4.01';
  CopyrightString = '� Marco Cant� 1996-1999';

/////////// support code //////////////

/////////// code from DdhRttiH, previoulsy RttiHelp,
/////////// the RTTI helper functions

// redeclaration of RTTI type
type
  TParamData = record
    Flags: TParamFlags;
    ParamName: ShortString;
    TypeName: ShortString;
    // beware: string length varies!!!
  end;
  PParamData = ^TParamData;

procedure SortPropList(PropList: PPropList; PropCount: Integer); forward;

// show RTTI information for method pointers
procedure ShowMethod (pti: PTypeInfo; sList: TStrings);
var
  ptd: PTypeData;
  pParam: PParamData;
  nParam: Integer;
  Line: string;
  pTypeString, pReturnString: ^ShortString;
begin
  // protect against misuse
  if pti^.Kind <> tkMethod then
    raise Exception.Create ('Invalid type information');

  // get a pointer to the TTypeData structure
  ptd := GetTypeData (pti);

  // 1: access the TTypeInfo structure
  sList.Add ('Type Name: ' + pti^.Name);
  sList.Add ('Type Kind: ' + GetEnumName (
    TypeInfo (TTypeKind),
    Integer (pti^.Kind)));

  // 2: access the TTypeData structure
  sList.Add ('Method Kind: ' + GetEnumName (
    TypeInfo (TMethodKind),
    Integer (ptd^.MethodKind)));
  sList.Add ('Number of parameter: ' +
    IntToStr (ptd^.ParamCount));

  // 3: access to the ParamList
  // get the initial pointer and
  // reset the parameters counter
  pParam := PParamData (@(ptd^.ParamList));
  nParam := 1;
  // loop until all parameters are done
  while nParam <= ptd^.ParamCount do
  begin
    // read the information
    Line := 'Param ' + IntToStr (nParam) + ' > ';
    // add type of parameter
    if pfVar in pParam^.Flags then
      Line := Line + 'var ';
    if pfConst in pParam^.Flags then
      Line := Line + 'const ';
    if pfOut in pParam^.Flags then
      Line := Line + 'out ';
    // get the parameter name
    Line := Line + pParam^.ParamName + ': ';
    // one more type of parameter
    if pfArray in pParam^.Flags then
      Line := Line + ' array of ';
    // the type name string must be located...
    // moving a pointer past the params and
    // the string (including its size byte)
    pTypeString := Pointer (Integer (pParam) +
      sizeof (TParamFlags) +
      Length (pParam^.ParamName) + 1);
    // add the type name
    Line := Line + pTypeString^;
    // finally, output the string
    sList.Add (Line);
    // move the pointer to the next structure,
    // past the two strings (including size byte)
    pParam := PParamData (Integer (pParam) +
      sizeof (TParamFlags) +
      Length (pParam^.ParamName) + 1 +
      Length (pTypeString^) + 1);
    // increase the parameters counter
    Inc (nParam);
  end;
  // show the return type if a function
  if ptd^.MethodKind = mkFunction then
  begin
    // at the end, instead of a param data,
    // there is the return string
    pReturnString := Pointer (pParam);
    sList.Add ('Returns > ' + pReturnString^);
  end;
end;

// show RTTI information for class type
procedure ShowClass (pti: PTypeInfo; sList: TStrings);
var
  ptd: PTypeData;
  ppi: PPropInfo;
  pProps: PPropList;
  nProps, I: Integer;
  ParentClass: TClass;
begin
  // protect against misuse
  if pti.Kind <> tkClass then
    raise Exception.Create ('Invalid type information');

  // get a pointer to the TTypeData structure
  ptd := GetTypeData (pti);

  // access the TTypeInfo structure
  sList.Add ('Type Name: ' + pti.Name);
  sList.Add ('Type Kind: ' + GetEnumName (
    TypeInfo (TTypeKind),
    Integer (pti.Kind)));

  // access the TTypeData structure
  {omitted: the same information of pti^.Name...
  sList.Add ('ClassType: ' + ptd^.ClassType.ClassName);}
  sList.Add ('Size: ' + IntToStr (
    ptd.ClassType.InstanceSize) + ' bytes');
  sList.Add ('Defined in: ' + ptd.UnitName + '.pas');

  // add the list of parent classes (if any)
  ParentClass := ptd.ClassType.ClassParent;
  if ParentClass <> nil then
  begin
    sList.Add ('');
    sList.Add ('=== Parent classes ===');
    while ParentClass <> nil do
    begin
      sList.Add (ParentClass.ClassName);
      ParentClass := ParentClass.ClassParent;
    end;
  end;

  // add the list of properties (if any)
  nProps := ptd.PropCount;
  if nProps > 0 then
  begin
    // format the initial output
    sList.Add ('');
    sList.Add ('=== Properties (' +
      IntToStr (nProps) + ') ===');
    // allocate the required memory
    GetMem (pProps, sizeof (PPropInfo) * nProps);
    // protect the memory allocation
    try
      // fill the TPropList structure
      // pointed to by pProps
      GetPropInfos(pti, pProps);
      // sort the properties
      SortPropList(pProps, nProps);
      // show name and data type of each property
      for I := 0 to nProps - 1 do
      begin
        ppi := pProps [I];
        sList.Add (ppi.Name + ': ' +
          ppi.PropType^.Name);
      end;
    finally
      // free the allocated memmory
      FreeMem (pProps, sizeof (PPropInfo) * nProps);
    end;
  end;
end;

// list enumerated values (used by next routine)
procedure ListEnum (pti: PTypeInfo;
  sList: TStrings; ShowIndex: Boolean);
var
  I: Integer;
begin
  with GetTypeData(pti)^ do
    for I := MinValue to MaxValue do
      if ShowIndex then
        sList.Add ('  ' + IntToStr (I) + '. ' +
         GetEnumName (pti, I))
      else
        sList.Add (GetEnumName (pti, I));
end;

// show RTTI information for ordinal types
procedure ShowOrdinal (pti: PTypeInfo; sList: TStrings);
var
  ptd: PTypeData;
begin
  // protect against misuse
  if not (pti^.Kind in [tkInteger, tkChar,
      tkEnumeration, tkSet, tkWChar]) then
    raise Exception.Create ('Invalid type information');

  // get a pointer to the TTypeData structure
  ptd := GetTypeData (pti);

  // access the TTypeInfo structure
  sList.Add ('Type Name: ' + pti^.Name);
  sList.Add ('Type Kind: ' + GetEnumName (
    TypeInfo (TTypeKind),
    Integer (pti^.Kind)));

  // access the TTypeData structure
  sList.Add ('Implement: ' + GetEnumName (
    TypeInfo (TOrdType),
    Integer (ptd^.OrdType)));

  // a set has no min and max
  if pti^.Kind <> tkSet then
  begin
    sList.Add ('Min Value: ' + IntToStr (ptd^.MinValue));
    sList.Add ('Max Value: ' + IntToStr (ptd^.MaxValue));
  end;

  // add the enumeration base type
  // and the list of the values
  if pti^.Kind = tkEnumeration then
  begin
    sList.Add ('Base Type: ' + (ptd^.BaseType)^.Name);
    sList.Add ('');
    sList.Add ('Values...');
    ListEnum (pti, sList, True);
  end;

  // show RRTI info about set base type
  if  pti^.Kind = tkSet then
  begin
    sList.Add ('');
    sList.Add ('Set base type information...');
    ShowOrdinal (ptd^.CompType^, sList);
  end;
end;

// generic procedure, calling the other ones
procedure ShowRTTI (pti: PTypeInfo; sList: TStrings);
begin
  case pti^.Kind of
    tkInteger, tkChar, tkEnumeration, tkSet, tkWChar:
      ShowOrdinal (pti, sList);
    tkMethod:
      ShowMethod (pti, sList);
    tkClass:
      Showclass (pti, sList);
    tkString, tkLString:
    begin
      sList.Add ('Type Name: ' + pti^.Name);
      sList.Add ('Type Kind: ' + GetEnumName (
        TypeInfo (TTypeKind), Integer (pti^.Kind)));
    end
    else
      sList.Add ('Undefined type information');
  end;
end;

// show the RTTI information inside a modal dialog box
procedure ShowRttiDetail (pti: PTypeInfo);
var
  Form: TForm;
begin
  Form := TForm.Create (Application);
  try
    Form.Width := 250;
    Form.Height := 300;
    // middle of the screen
    Form.Left := Screen.Width div 2 - 125;
    Form.Top := Screen.Height div 2 - 150;
    Form.Caption := 'RTTI Details for ' + pti.Name;
    Form.BorderStyle := bsDialog;
    with TMemo.Create (Form) do
    begin
      Parent := Form;
      Width := Form.ClientWidth;
      Height := Form.ClientHeight - 35;
      ReadOnly := True;
      Color := clBtnFace;
      ShowRTTI (pti, Lines);
    end;
    with TBitBtn.Create (Form) do
    begin
      Parent := Form;
      Left := Form.ClientWidth div 3;
      Width := Form.ClientWidth div 3;
      Top := Form.ClientHeight - 32;
      Height := 30;
      Kind := bkOK;
    end;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

// support function: get the form (or data module)
// owning the component
function GetOwnerForm (Comp: TComponent): TComponent;
begin
  while not (Comp is TForm) and
      not (Comp is TDataModule) do
    Comp := Comp.Owner;
  Result := Comp;
end;

// from the Bits1 example (Chapter 1)
function IsBitOn (Value: Integer; Bit: Byte): Boolean;
begin
  Result := (Value and (1 shl Bit)) <> 0;
end;

// support function: convert set value
// into a string as in the Object Inspector

function SetToString (Value: Cardinal;
  pti: PTypeInfo): string;
var
  Res: String;  // result
  BaseType: PTypeInfo;
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  // open the expression
  Res := '[';
  // get the type of the enumeration
  // the set is based onto
  BaseType := GetTypeData(pti).CompType^;
  // for each possible value
  for I := GetTypeData (BaseType).MinValue
      to GetTypeData (BaseType).MaxValue do
    // if the bit I (computed as 1 shl I) is set,
    // then the corresponding element is in the set
    // (the and is a bitwise and, not a boolean operation)
    if IsBitOn (Value, I) then
    begin
      // add the name of the element
      Res := Res + GetEnumName (BaseType, I) + ', ';
      Found := True;
    end;
  if Found then
    // remove the final comma and space (2 chars)
    Res := Copy (Res, 1, Length (Res) - 2);
  // close the expression
  Result := Res + ']';
end;

// return the property value as a string
function GetPropValAsString (Obj: TObject;
  PropInfo: PPropInfo): string;
var
  Pt: Pointer;
  Word: Cardinal;
begin
  case PropInfo.PropType^.Kind of

    tkUnknown:
      Result := 'Unknown type';

    tkChar:
    begin
      Word := GetOrdProp (Obj, PropInfo);
      if Word > 32 then
        Result := Char (Word)
      else
        Result := '#' + IntToStr (Word);
    end;

    tkWChar:
    begin
      Word := GetOrdProp (Obj, PropInfo);
      if Word > 32 then
        Result := WideChar (Word)
      else
        Result := '#' + IntToStr (Word);
    end;


    tkInteger:
      if PropInfo.PropType^.Name = 'TColor' then
        Result := ColorToString (GetOrdProp (Obj, PropInfo))
      else if PropInfo.PropType^.Name = 'TCursor' then
        Result := CursorToString (GetOrdProp (Obj, PropInfo))
      else
        Result := Format ('%d', [GetOrdProp (Obj, PropInfo)]);

    tkEnumeration:
      Result := GetEnumName (PropInfo.PropType^,
        GetOrdProp (Obj, PropInfo));

    tkFloat:
      Result := FloatToStr (GetFloatProp (Obj, PropInfo));

    tkString, tkLString:
      Result := GetStrProp (Obj, PropInfo);

    tkSet:
      Result := SetToString (GetOrdProp (Obj, PropInfo),
        PropInfo.PropType^);

    tkClass:
    begin
      Pt := Pointer (GetOrdProp (Obj, PropInfo));
      if Pt = nil then
        Result := '(None)'
      else
        Result := Format ('(Object %p)', [Pt]);
    end;

    tkMethod:
    begin
      Pt := GetMethodProp (Obj, PropInfo).Code;
      if Pt <> nil then
        Result := GetOwnerForm (Obj as TComponent).
          MethodName (Pt)
      else
        Result := '';
    end;

    tkVariant:
      Result := GetVariantProp (Obj, PropInfo);

    tkArray, tkRecord, tkInterface:
      Result := 'Unsupported type';

    else
      Result := 'Undefined type';
  end;
end;

// code extracted from TypInfo.pas
procedure SortPropList(PropList: PPropList; PropCount: Integer); assembler;
asm
        { ->    EAX Pointer to prop list        }
        {       EDX Property count              }
        { <-    nothing                         }

        PUSH    EBX
        PUSH    ESI
        PUSH    EDI
        MOV     ECX,EAX
        XOR     EAX,EAX
        DEC     EDX
        CALL    @@qsort
        POP     EDI
        POP     ESI
        POP     EBX
        JMP     @@exit

@@qsort:
        PUSH    EAX
        PUSH    EDX
        LEA     EDI,[EAX+EDX]           { pivot := (left + right) div 2 }
        SHR     EDI,1
        MOV     EDI,[ECX+EDI*4]
        ADD     EDI,OFFSET TPropInfo.Name
@@repeat:                               { repeat                        }
@@while1:
        CALL    @@compare               { while a[i] < a[pivot] do inc(i);}
        JAE     @@endWhile1
        INC     EAX
        JMP     @@while1
@@endWhile1:
        XCHG    EAX,EDX
@@while2:
        CALL    @@compare               { while a[j] > a[pivot] do dec(j);}
        JBE     @@endWhile2
        DEC     EAX
        JMP     @@while2
@@endWhile2:
        XCHG    EAX,EDX
        CMP     EAX,EDX                 { if i <= j then begin          }
        JG      @@endRepeat
        MOV     EBX,[ECX+EAX*4]         { x := a[i];                    }
        MOV     ESI,[ECX+EDX*4]         { y := a[j];                    }
        MOV     [ECX+EDX*4],EBX         { a[j] := x;                    }
        MOV     [ECX+EAX*4],ESI         { a[i] := y;                    }
        INC     EAX                     { inc(i);                       }
        DEC     EDX                     { dec(j);                       }
                                        { end;                          }
        CMP     EAX,EDX                 { until i > j;                  }
        JLE     @@repeat

@@endRepeat:
        POP     ESI
        POP     EBX

        CMP     EAX,ESI
        JL      @@rightNonEmpty         { if i >= right then begin      }
        CMP     EDX,EBX
        JG      @@leftNonEmpty1         { if j <= left then exit        }
        RET

@@leftNonEmpty1:
        MOV     EAX,EBX
        JMP     @@qsort                 { qsort(left, j)                }

@@rightNonEmpty:
        CMP     EAX,EBX
        JG      @@leftNonEmpty2
        MOV     EDX,ESI                 { qsort(i, right)               }
        JMP     @@qsort
@@leftNonEmpty2:
        PUSH    EAX
        PUSH    ESI
        MOV     EAX,EBX
        CALL    @@qsort                 { qsort(left, j)                }
        POP     EDX
        POP     EAX
        JMP     @@qsort                 { qsort(i, right)               }

@@compare:
        PUSH    EAX
        PUSH    EDI
        MOV     ESI,[ECX+EAX*4]
        ADD     ESI,OFFSET TPropInfo.Name
        PUSH    ESI
        XOR     EBX,EBX
        MOV     BL,[ESI]
        INC     ESI
        CMP     BL,[EDI]
        JBE     @@firstLenSmaller
        MOV     BL,[EDI]
@@firstLenSmaller:
        INC     EDI
        TEST    BL,BL
        JE      @@endLoop
@@loop:
        MOV     AL,[ESI]
        MOV     AH,[EDI]
        AND     EAX,$DFDF
        CMP     AL,AH
        JNE     @@difference
        INC     ESI
        INC     EDI
        DEC     EBX
        JNZ     @@loop
@@endLoop:
        POP     ESI
        POP     EDI
        MOV     AL,[ESI]
        MOV     AH,[EDI]
        CMP     AL,AH
        POP     EAX
        RET
@@difference:
        POP     ESI
        POP     EDI
        POP     EAX
        RET
@@exit:
end;

////////// code form Math.pas /////////////

function IntPower(Base: Extended; Exponent: Integer): Extended;
asm
        mov     ecx, eax
        cdq
        fld1                      { Result := 1 }
        xor     eax, edx
        sub     eax, edx          { eax := Abs(Exponent) }
        jz      @@3
        fld     Base
        jmp     @@2
@@1:    fmul    ST, ST            { X := Base * Base }
@@2:    shr     eax,1
        jnc     @@1
        fmul    ST(1),ST          { Result := Result * X }
        jnz     @@1
        fstp    st                { pop X from FPU stack }
        cmp     ecx, 0
        jge     @@3
        fld1
        fdivrp                    { Result := 1 / Result }
@@3:
        fwait
end;

////// component //////
var
  Created: Boolean = False;

constructor TCantObjectDebugger.Create (AOwner: TComponent);
begin
  if Created then
    raise Exception.Create ('Only one debugger, please!')
  else
    Created := True;

  inherited Create (AOwner);
  fCopyright := CopyrightString;
  if not (csDesigning in ComponentState) then
  begin
    CantObjDebForm := TCantObjDebForm.
      Create (Application);
    if fOnTop then
    begin
      // set topmost style
      CantObjDebForm.FormStyle := fsStayOnTop;
      CantObjDebForm.TopMost1.Checked := True
    end;
    CantObjDebForm.Timer1.Enabled := True;
  end;
end;

procedure Register;
begin
  RegisterComponents('Cantools', [TCantObjectDebugger]);
end;

////// form //////

{initialize the local data to nil and so on...}
procedure TCantObjDebForm.FormCreate(Sender: TObject);
begin
  CurrForm := nil;
  CurrComp := nil;
  RealComp := nil;
  EditingSub := False;
  // show the first page
  PageControl1.ActivePage := TabSheet1;
  // set first line
  sgProp.Cells [0, 0] := 'Type: (click for detail)';
  sgEvt.Cells [0, 0] := 'Type: (click for detail)';
  sgData.Cells [0, 0] := 'Type:';
  // fill input combos
  Combo := ComboCursor;
  GetCursorValues (AddToCombo);
  Combo := ComboColor;
  GetColorValues (AddToCombo);
end;

{call-back used in the code above...}
procedure TCantObjDebForm.AddToCombo (const S: String);
begin
  Combo.Items.Add (S);
end;

{fill the FormsCombo with the names of the forms of the
current project keep the curent element selected, unless it
has been destroyed. In this last case use the MainForm
as selected form.}
procedure TCantObjDebForm.UpdateFormsCombo;
var
  I, nForm, Pos: Integer;
  Form: TForm;
begin
  Screen.Cursor := crHourglass;
  cbForms.Items.BeginUpdate;
  try
    cbForms.Items.Clear;
    // for each form of the program
    for nForm := 0 to Screen.FormCount - 1 do
    begin
      Form := Screen.Forms [nForm];
      // if the form is not the one of the ObjectDebugger, add it
      if Form <> self then
        cbForms.Items.AddObject (
          Format ('%s (%s)', [Form.Caption, Form.ClassName]),
          Form);
    end;
    // for each data module
    for I := 0 to Screen.DataModuleCount - 1 do
      cbForms.Items.AddObject (
        Format ('%s (%s)',
          [Screen.DataModules [I].Name,
          Screen.DataModules [I].ClassName]),
          Screen.DataModules [I]);
    // re-select the current form, if exists
    if not Assigned (CurrForm) then
      CurrForm := Application.MainForm;
    Pos := cbForms.Items.IndexOfObject (CurrForm);
    if Pos < 0 then
    begin
      // was a destroyed form, retry...
      CurrForm := Application.MainForm;
      Pos := cbForms.Items.IndexOfObject (CurrForm);
    end;
    cbForms.ItemIndex := Pos;
  finally
    cbForms.Items.EndUpdate;
    Screen.Cursor := crDefault;
  end;
  UpdateCompsCombo;
end;

procedure TCantObjDebForm.cbFormsChange(Sender: TObject);
begin
  // save the current form or data module
  CurrForm := cbForms.Items.Objects [
    cbForms.ItemIndex] as TComponent;
  // update the list of components
  UpdateCompsCombo;
end;

procedure TCantObjDebForm.UpdateCompsCombo;
var
  nComp, Pos: Integer;
  Comp: TComponent;
begin
  cbComps.Items.Clear;
  cbComps.Items.AddObject (Format ('%s: %s',
    [CurrForm.Name, CurrForm.ClassName]), CurrForm);
  for nComp := 0 to CurrForm.ComponentCount - 1 do
  begin
    Comp := CurrForm.Components [nComp];
    cbComps.Items.AddObject (Format ('%s: %s',
      [Comp.Name, Comp.ClassName]), Comp);
  end;
  // reselect the current component, if any
  if not Assigned (CurrComp) then
    CurrComp := CurrForm;
  Pos := cbComps.Items.IndexOfObject (CurrComp);
  if Pos < 0 then
    Pos := cbComps.Items.IndexOfObject (CurrForm);
  cbComps.ItemIndex := Pos;
  UpdateProps;
  UpdateData;
end;

procedure TCantObjDebForm.cbCompsChange(Sender: TObject);
begin
  // select the new component
  CurrComp := cbComps.Items.Objects [
    cbComps.ItemIndex] as TComponent;
  // update the grids
  UpdateProps;
  UpdateData;
end;

procedure TCantObjDebForm.UpdateProps;
// update property and event pages
var
  PropList, SubPropList: TPropList;
  NumberOfProps, NumberOfSubProps, // total number of properties
  nProp, nSubProp, // property loop counter
  nRowProp, nRowEvt: Integer; // items actually added
  SubObj: TPersistent;
begin
  // reset the type
  sgProp.Cells [1, 0] := '';
  sgEvt.Cells [1, 0] := '';

  // get the number of properties
  NumberOfProps := GetTypeData(CurrComp.ClassInfo).PropCount;
  // exaggerate in size...
  sgProp.RowCount := NumberOfProps;
  sgEvt.RowCount := NumberOfProps;

  // get the list of properties and sort it
  GetPropInfos (CurrComp.ClassInfo, @PropList);
  SortPropList(@PropList, NumberOfProps);

  // show the name of each property
  // adding it to the proper page
  nRowProp := 1;
  nRowEvt := 1;
  for nProp := 0 to NumberOfProps - 1 do
  begin
    // if it is a real property
    if PropList[nProp].PropType^.Kind <> tkMethod then
    begin
      // name
      sgProp.Cells [0, nRowProp] := PropList[nProp].Name;
      // value
      sgProp.Cells [1, nRowProp] := GetPropValAsString (
        CurrComp, PropList [nProp]);
      // data
      sgProp.Objects [0, nRowProp] := TObject (PropList[nProp]);
      sgProp.Objects [1, nRowProp] := nil;

      // move to the next line
      Inc (nRowProp);

      // if the property is a class
      if (PropList[nProp].PropType^.Kind = tkClass) then
      begin
        SubObj := TPersistent (GetOrdProp (
          CurrComp, PropList[nProp]));
        if (SubObj <> nil) and not (SubObj is TComponent) then
        begin
          NumberOfSubProps := GetTypeData(SubObj.ClassInfo).PropCount;
          if NumberOfSubProps > 0 then
          begin
            // add plus sign
            sgProp.Cells [0, nRowProp - 1] := '+' +
              sgProp.Cells [0, nRowProp - 1];
            // add space for subproperties...
            sgProp.RowCount := sgProp.RowCount + NumberOfSubProps;
            // get the list of subproperties and sort it
            GetPropInfos (subObj.ClassInfo, @SubPropList);
            SortPropList(@SubPropList, NumberOfSubProps);
            // show the name of each subproperty
            for nSubProp := 0 to NumberOfSubProps - 1 do
            begin
              // if it is a real property
              if SubPropList[nSubProp].PropType^.Kind <> tkMethod then
              begin
                // name (indented)
                sgProp.Cells [0, nRowProp] :=
                   '    ' + SubPropList[nSubProp].Name;
                // value
                sgProp.Cells [1, nRowProp] := GetPropValAsString (
                  SubObj, SubPropList [nSubProp]);
                // data
                sgProp.Objects [0, nRowProp] :=
                  TObject (SubPropList[nSubProp]);
                sgProp.Objects [1, nRowProp] := SubObj;
                Inc (nRowProp);
              end; // if
            end; // for
          end;
        end;
      end; // adding subproperties
    end
    else // it is an event
    begin
      // name
      sgEvt.Cells [0, nRowEvt] := PropList[nProp].Name;
      // value
      sgEvt.Cells [1, nRowEvt] := GetPropValAsString (
        CurrComp, PropList [nProp]);
      // data
      sgEvt.Objects [0, nRowEvt] := TObject (PropList[nProp]);
      // next
      Inc (nRowEvt);
    end;
  end; // for
  // set the actual rows
  sgProp.RowCount := nRowProp;
  sgEvt.RowCount := nRowEvt;
end;

procedure TCantObjDebForm.UpdateData;
var
  nRow: Integer;

  procedure AddLine(Name, Value: string; pti: PTypeInfo);
  begin
    sgData.Cells [0, nRow] := Name;
    sgData.Cells [1, nRow] := Value;
    sgData.Objects [0, nRow] := Pointer (pti);
    sgProp.Objects [1, nRow] := nil;
    Inc (nRow);
  end;

begin
  // reset type
  sgEvt.Cells [1, 0] := '';

  nRow := 1;
  // exaggerate...
  sgData.RowCount := 15;
  // add component runtime properties
  AddLine ('ComponentCount',
    IntToStr (CurrComp.ComponentCount),
    TypeInfo (Integer));
  {useless... AddLine ('ComponentState', SetToString (
    Byte (CurrComp.ComponentState),  TypeInfo (TComponentState)));}
  AddLine ('ComponentIndex',
    IntToStr (CurrComp.ComponentIndex),
    TypeInfo (Integer));
  AddLine ('ComponentStyle',
    SetToString (Byte (CurrComp.ComponentStyle),
      TypeInfo (TComponentStyle)),
    TypeInfo (TComponentStyle));
  if CurrComp.Owner <> nil then
    if CurrComp.Owner = Application then
      AddLine ('Owner',
        'Application',
        TypeInfo (TComponent))
    else
      AddLine ('Owner',
        CurrComp.Owner.Name,
        TypeInfo (TComponent))
  else // owner = nil
    AddLine ('Owner',
      'none',
      TypeInfo (TComponent));
  // add control runtme properties
  if CurrComp is TControl then
    with TControl (CurrComp) do
    begin
      AddLine ('ControlState',
        SetToString (Word (ControlState), TypeInfo (TControlState)),
        TypeInfo (TControlState));
      AddLine ('ControlStyle',
        SetToString (LongInt (ControlStyle), TypeInfo (TControlStyle)),
        TypeInfo (TControlStyle));
      if Parent <> nil then
        AddLine ('Parent',
          Parent.Name,
          TypeInfo(TWinControl))
        else
        AddLine ('Parent',
          'none',
          TypeInfo(TWinControl));
      {3.0 only: AddLine ('WindowProc', IntToStr (Integer (WindowProc)));}
    end;

  // add win control runtime properties
  if CurrComp is TWinControl then
    with TWinControl (CurrComp) do
    begin
      // AddLine ('Brush', // show handle + style + color ?
      AddLine ('ControlCount',
        IntToStr (ControlCount),
        TypeInfo (Integer));
      AddLine ('Handle',
        '$' + IntToHex (Handle, 8),
        TypeInfo (Hwnd));
      // 3.0 only: AddLine ('ParentWindow (Handle)', IntToHex (ParentWindow, 16));
      AddLine ('Showing',
        GetEnumName (TypeInfo(Boolean), Integer (Showing)),
        TypeInfo (Boolean));
    end;
  // set the actual number of rows
  sgData.RowCount := nRow;
end;

////////////////////////////////////////////////////////////
//////////// string grid selections and clicks /////////////
////////////////////////////////////////////////////////////

procedure TCantObjDebForm.sgPropSelectCell(Sender: TObject; Col, Row: Longint;
  var CanSelect: Boolean);
var
  sg: TStringGrid;
  ppInfo: PPropInfo;
  I: Integer;

procedure PlaceControl (Ctrl: TWinControl);
begin
  Ctrl.BringToFront;
  Ctrl.Show;
  Ctrl.BoundsRect := sg.CellRect (Col, Row);
  Ctrl.SetFocus;
end;

begin
  sg := Sender as TStringGrid;
  // get the data and show it in the first line
  ppInfo := PPropInfo (sg.Objects [0, Row] );
  if (ppInfo = nil) or (sg = sgData) then
    Exit;
  sg.Cells [1, 0] := ppInfo.PropType^.Name;
  sg.Objects [1, 0] := Pointer (ppInfo.PropType^);
  // if second column activate the proper editor
  if Col = 1 then
  begin
    CurrProp := ppInfo;
    CurrRow := Row;
    // if it is a subproperty, select the value of
    // the property as the current component
    if sg.Objects [1, Row] <> nil then
    begin
      RealComp := CurrComp;
      EditingSub := True;
      CurrComp := TComponent (sg.Objects [1, Row]);
    end;

    ////////// depending on the type, show up an editor
    case ppInfo.PropType^.Kind of

      tkInteger: ////////////////////////////////////////
      begin
        if ppInfo.PropType^.Name = 'TCursor' then
        begin
          ComboCursor.Text := GetPropValAsString (CurrComp, ppInfo);
          PlaceControl (ComboCursor);
        end
        else if ppInfo.PropType^.Name = 'TColor' then
        begin
          ComboColor.Tag := GetOrdProp (CurrComp, ppInfo);
          ComboColor.Text := GetPropValAsString (CurrComp, ppInfo);
          PlaceControl (ComboColor)
        end else
        begin
          EditNum.Text := GetPropValAsString (CurrComp, ppInfo);
          PlaceControl (EditNum);
          EditModified := False;
        end;
      end;

      tkChar: ////////////////////////////////////////////
      begin
        EditCh.Text := GetPropValAsString (CurrComp, ppInfo);
        PlaceControl (EditCh);
        EditModified := False;
      end;

      tkEnumeration: /////////////////////////////////////
      begin
        ComboEnum.Clear;
        ListEnum (ppInfo.PropType^, ComboEnum.Items, False);
        ComboEnum.ItemIndex := ComboEnum.Items.IndexOf (
          GetPropValAsString (CurrComp, ppInfo));
        PlaceControl (ComboEnum);
      end;

      tkString, tkLString: //////////////////////////
      begin
        EditStr.Text := GetPropValAsString (
          CurrComp, ppInfo);
        PlaceControl (EditStr);
        EditModified := False;
      end;

      tkSet: ////////////////////////////////////////
      begin
        ListSet.Clear;
        ListEnum (
          GetTypeData (ppInfo.PropType^).CompType^,
          ListSet.Items, False);
        // select the "on" items
        for I := 0 to ListSet.Items.Count - 1 do
          ListSet.Selected [I] :=
            IsBitOn (GetOrdProp (CurrComp, ppINfo), I);
        PlaceControl (ListSet);
        ListSet.Height := ListSet.Height * 8;
      end;
      // tkClass: //// see double click...
    end;
  end;
end;

// create and show a dialog box a string list editor..
procedure TCantObjDebForm.EditStringList (Str: TStrings);
var
  F: TForm;
  I: Integer;
  Memo1: TMemo;
begin
  F := TForm.Create (Application);
  try
    F.Width := 250;
    F.Height := 300;
    // middle of the screen
    F.Left := Screen.Width div 2 - 125;
    F.Top := Screen.Height div 2 - 150;
    F.Caption := 'StringList Editor for ' + CurrProp.Name;
    F.BorderStyle := bsDialog;
    Memo1 := TMemo.Create (F);
    with Memo1 do
    begin
      Parent := F;
      Width := F.ClientWidth;
      Height := F.ClientHeight - 30;
      for I := 0 to Str.Count - 1 do
        Lines.Add (Str [I]);
    end;
    with TBitBtn.Create (F) do
    begin
      Parent := F;
      Width := F.ClientWidth div 2;
      Top := F.ClientHeight - 30;
      Height := 30;
      Kind := bkOK;
    end;
    with TBitBtn.Create (F) do
    begin
      Parent := F;
      Width := F.ClientWidth div 2;
      Left := F.ClientWidth div 2;
      Top := F.ClientHeight - 30;
      Height := 30;
      Kind := bkCancel;
    end;
    if F.ShowModal = mrOk then
    begin
      Str.Clear;
      for I := 0 to Memo1.Lines.Count - 1 do
        Str.Add (Memo1.Lines [I]);
    end;
  finally
    F.Free;
  end;
end;

procedure TCantObjDebForm.sgDataSelectCell(Sender: TObject; Col, Row: Longint;
  var CanSelect: Boolean);
var
  sg: TStringGrid;
  ptInfo: PTypeInfo;
begin
  sg := Sender as TStringGrid;
  // get the data and show it in the first line
  ptInfo := PTypeInfo (sg.Objects [0, Row] );
  sg.Cells [1, 0] := ptInfo.Name;
  sg.Objects [1, 0] := Pointer (ptInfo);
end;

procedure TCantObjDebForm.sgMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  sg: TStringGrid;
  ACol, ARow: Longint;
begin
  sg := Sender as TStringGrid;
  sg.MouseToCell (X, Y, ACol, ARow);
  if (ARow = 0) and (sg.Cells [1, 0] <> '') then
    ShowRttiDetail (PTypeInfo (sg.Objects [1, 0]));
end;

//////////////////////////////////////
///// menu items and UI //////////////
//////////////////////////////////////

procedure TCantObjDebForm.RefreshForms1Click(Sender: TObject);
begin
  UpdateFormsCombo;
end;

procedure TCantObjDebForm.RefreshComponents1Click(Sender: TObject);
begin
  UpdateCompsCombo;
end;

procedure TCantObjDebForm.About1Click(Sender: TObject);
begin
  // Show an about box
  MessageDlg (VersionDescription +
    #13+ VersionRelease +
    #13#13'Copyright Marco Cant� 1997',
    mtINformation, [mbOk], 0);
end;

procedure TCantObjDebForm.RefreshValues1Click(Sender: TObject);
begin
  UpdateProps;
end;

//////////////////////////////////
/////// special editors... ///////
//////////////////////////////////

////// edit strings //////

procedure TCantObjDebForm.EditStrExit(Sender: TObject);
begin
  try
    if EditModified then
      SetStrProp (CurrComp, CurrProp, EditStr.Text);
  finally
    RefreshOnExit (Sender);
  end;
end;

////////// edit num /////////////

procedure TCantObjDebForm.EditNumExit(Sender: TObject);
begin
  try
    if EditModified then
      SetOrdProp (CurrComp, CurrProp, StrToInt (EditNum.Text));
    RefreshOnExit (Sender);
  except
    on EConvertError do
    begin
      ShowMessage ('Not a number');
      EditNum.SetFocus;
    end;
  end;
end;

procedure TCantObjDebForm.EditNumKeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9']) and not (Key = #8) then
    Key := #0;
end;

///////// combo color /////////

procedure TCantObjDebForm.ComboColorDblClick(Sender: TObject);
var
  Color: LongInt;
  ColName: string;
  nItem: Integer;
begin
  if not IdentToColor (ComboColor.Text, Color) then
    Color := TColor (ComboColor.Tag);
  ColorDialog1.Color := Color;
  if ColorDialog1.Execute then
  begin
    ComboColor.Tag := ColorDialog1.Color;
    ColName := ColorToString (ColorDialog1.Color);
    nItem := ComboColor.Items.IndexOf (ColName);
    if nItem >= 0 then
      ComboColor.ItemIndex := nItem
    else
      ComboColor.Text := ColName;
    ComboColorChange (ComboColor);
  end;
end;

procedure TCantObjDebForm.ComboColorChange(Sender: TObject);
var
  Color: LongInt;
begin
  if IdentToColor (ComboColor.Text, Color) then
    ComboColor.Tag := Color
  else
    Color := TColor (ComboColor.Tag);
  SetOrdProp (CurrComp, CurrProp, Color);
end;

///////// combo cursor ///////////

procedure TCantObjDebForm.ComboCursorChange(Sender: TObject);
begin
  SetOrdProp (CurrComp, CurrProp,
    StringToCursor (ComboCursor.Text));
end;

////////// combo enum /////////

procedure TCantObjDebForm.ComboEnumChange(Sender: TObject);
begin
  SetOrdProp (CurrComp, CurrProp,
    GetEnumValue (CurrProp.PropType^, ComboEnum.Text));
end;

procedure TCantObjDebForm.ComboEnumDblClick(Sender: TObject);
begin
  with ComboEnum do
    if ItemIndex < Items.Count - 1 then
      ItemIndex := ItemIndex + 1
    else
      ItemIndex := 0;
  ComboEnumChange (ComboEnum);
end;

///////// edit ch //////////

procedure TCantObjDebForm.EditChExit(Sender: TObject);
var
  Ch: Char;
begin
  try
    if EditModified then
    begin
      if Length (EditCh.Text) = 1 then
        Ch := EditCh.Text [1]
      else if EditCh.Text [1] = '#' then
        Ch := Char (StrToInt (Copy (
          EditCh.Text, 2, Length (EditCh.Text) - 1)))
      else
        raise EConvertError.Create ('Error');
      SetOrdProp (CurrComp, CurrProp, Word (Ch));
    end;
    RefreshOnExit (Sender);
  except
    on EConvertError do
    begin
      ShowMessage ('Not a valid character');
      EditCh.SetFocus;
    end;
  end;
end;

////////// list set ///////////

procedure TCantObjDebForm.ListSetClick(Sender: TObject);
var
  Value: Word;
  I: Integer;
begin
  Value := 0;
  // update the value, scanning the list
  for I := 0 to ListSet.Items.Count - 1 do
    if ListSet.Selected [I] then
      Value := Value + Round (IntPower (2, I));
  SetOrdProp (CurrComp, CurrProp, Value);
end;

//// generic //////////

procedure TCantObjDebForm.RefreshOnExit(Sender: TObject);
begin
  sgProp.Cells [1, CurrRow] :=
    GetPropValAsString (CurrComp, CurrProp);
  (Sender as TWinControl).Hide;
  if EditingSub then
    CurrComp := RealComp;
end;

//////////// resizing /////////////////

procedure TCantObjDebForm.FormResize(Sender: TObject);
begin
  with cbForms do
    Width := self.ClientWidth - Left * 2;
  with cbComps do
    Width := self.ClientWidth - Left * 2;
  with sgProp do
    ColWidths [1] := ClientWidth - ColWidths [0] -
      GetSystemMetrics (sm_cxVScroll) - 2;
  with sgEvt do
    ColWidths [1] := ClientWidth - ColWidths [0] -
      GetSystemMetrics (sm_cxVScroll) - 2;
end;

procedure TCantObjDebForm.TopMost1Click(Sender: TObject);
begin
  TopMost1.Checked := not TopMost1.Checked;
  if TopMost1.Checked then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
end;

procedure TCantObjDebForm.sgPropDblClick(Sender: TObject);
begin
  if CurrProp <> nil then
  begin
    if CurrProp.PropType^.Name = 'TFont' then
    begin
      FontDialog1.Font.Assign (
        TFont (GetOrdProp (CurrComp, CurrProp)));
      if FontDialog1.Execute then
      begin
        TFont (GetOrdProp (CurrComp, CurrProp)).
          Assign (FontDialog1.Font);
        UpdateProps;
      end;
    end;

    // string list editor...
    if CurrProp.PropType^.Name = 'TStrings' then
      EditStringList (TStrings (
        GetOrdProp (CurrComp, CurrProp)));
  end;
end;

procedure TCantObjDebForm.Info1Click(Sender: TObject);
begin
  MessageDlg (VersionDescription + #13 +
    CopyrightString + #13#13 +
    'Usage: Select form and component you are interested in'#13 +
    '(also the form is listed among its components), and see'#13 +
    'its published properties, its events, and some mode data.'#13#13 +
    'Clicking on the first line shows RTTI information for'#13 +
    'the last property you''ve selected.'#13#13 +
    'Clicking on a value activates its editor (if available).'#13 +
    'Editors include: numbers, strings, characters,'#13 +
    'enumarations, sets, cursors, colors (double-click),'#13 +
    'string lists (double click).',
    mtInformation, [mbOk], 0);
end;

procedure TCantObjDebForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  // never close the form...
  Action := caMinimize;
end;

procedure TCantObjDebForm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  Show;
  UpdateFormsCombo;
end;

procedure TCantObjDebForm.EditChange(Sender: TObject);
begin
  EditModified := True;
end;

end.
