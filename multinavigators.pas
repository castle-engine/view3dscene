{
  Copyright 2003-2006 Michalis Kamburelis.

  This file is part of "view3dscene".

  "view3dscene" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "view3dscene" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "view3dscene"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit MultiNavigators;

{ modulik ulatwiajacy view3dmodelowi uzywac roznych Navigatorow
  z okienkiem typu TGLWindowNavigated. }

{$I openglmac.inc}

interface

uses SysUtils, KambiUtils, GLWindow, MatrixNavigation, Boxes3d, VectorMath,
  OpenGLh, KambiGLUtils;

type
  TNavigatorKind = (nkExaminer, nkWalker);

{ Call this ONCE on created glwin (glwin need not be after Init).
  This will take care of always providing proper glwin.Navigator
  for you. MoveAllowed will be used for collision detection
  when NavigatorKind in [nkWalker].

  You CAN NOT directly modify Navigators' properties
  (settings like HomeCamera, Rotation, but also general settings
  like OnMatrixchanged). You can do it only indirectly using this unit. }
procedure InitMultiNavigators(glwin: TGLWindowNavigated;
  MoveAllowed: TMoveAllowedFunc;
  GetCameraHeight: TGetCameraHeight);

{ Call this always when scene changes. Give new BoundingBox and
  HomeCamera settings for this new scene.
  This will call Init() functions for all navigators (that are ready
  for various values of  NavigatorKind).

  You must call InitMultiNavigators before using this. }
procedure SceneInitMultiNavigators(
  const ModelBox: TBox3d;
  const HomeCameraPos, HomeCameraDir, HomeCameraUp: TVector3Single;
  const CameraPreferredHeight, CameraRadius: Single);

const
  NavigatorNames: array[TNavigatorKind]of string =
   ('Examine', 'Walk');

function NavigatorKind: TNavigatorKind;
{ Note that Set/ChangeNavigatorKind call glwin.PostRedisplay and
  glwin.EventResize. They call glwin.EventResize so that you can adjust
  your projection settings (specifically, projection zNear/zFar)
  to different values of NavigatorKind.

  (why they call glwin.PostRedisplay is obvious --- changing
  Navigator in fact changed Navigator.Matrix, so we must
  do the same thing that would be done in Navigator.OnMatrixChange) }
procedure SetNavigatorKind(glwin: TGLWindowNavigated; Kind: TNavigatorKind);
procedure ChangeNavigatorKind(glwin: TGLWindowNavigated; change: integer);

{ This is MatrixWalker used when NavigationKind = nkWalker.
  Use this e.g. to set it's ProjectionMatrix. }
function MatrixWalker: TMatrixWalker;

{ Interpret and remove from ParStr(1) ... ParStr(ParCount)
  some params specific for this unit.
  Those params are documented in MultiNavigatorsOptionsHelp.

  Call this BEFORE InitMultiNavigators. }
procedure MultiNavigatorsParseParameters;

const
  MultiNavigatorsOptionsHelp =
  '  --navigation Examine|Walk'+nl+
  '                        Set initial navigation style';

implementation

uses ParseParametersUnit;

const
  NavigatorClasses: array[TNavigatorKind]of TMatrixNavigatorClass =
   (TMatrixExaminer, TMatrixWalker);

  NavigatorCreated: array[TNavigatorKind]of boolean =
   (true, true);

var
  FNavigatorKind: TNavigatorKind = nkExaminer;
  Navigators: array[TNavigatorKind]of TMatrixNavigator;

procedure SetNavigatorKindInternal(glwin: TGLWindowNavigated; value: TNavigatorKind);
{ This is private procedure in this module.
  Look at SetNavigatorKind for something that you can publicly use.
  This procedure does not do some things that SetNavigatorKind does
  because this is used from InitMultiNavigators. }
begin
 FNavigatorKind := value;
 glwin.Navigator := Navigators[FNavigatorKind];
 if FNavigatorKind in [nkWalker, nkFreeWalker] then
  glwin.NavWalker.PreferHomeUp := FNavigatorKind = nkWalker;
end;

procedure InitMultiNavigators(glwin: TGLWindowNavigated;
  MoveAllowed: TMoveAllowedFunc;
  GetCameraHeight: TGetCameraHeight);
var nk: TNavigatorKind;
begin
 { create navigators }
 for nk := Low(nk) to High(nk) do
  if NavigatorCreated[nk] then
   Navigators[nk] := NavigatorClasses[nk].Create(glwin.PostRedisplayOnMatrixChanged);

 { FreeWalker to ten sam obiekt co Walker; bedziemy mu tylko zmieniac
   PreferHomeUp gdy user bedzie zmienial navigatora; w ten sposob
   (zamiast robic osobne obiekty na Walker i FreeWalker) wartosci CameraPos/Dir/Up
   beda zawsze takie same dla nawigatorow Walker i FreeWalker (bo to bedzie tak
   naprawde jeden nawigator). }
 Navigators[nkFreeWalker] := Navigators[nkWalker];

 TMatrixWalker(Navigators[nkWalker]).OnMoveAllowed := MoveAllowed;
 TMatrixWalker(Navigators[nkWalker]).OnGetCameraHeight := GetCameraHeight;

 { init glwin.Navigator }
 glwin.OwnsNavigator := false;
 SetNavigatorKindInternal(glwin, FNavigatorKind);
end;

procedure SceneInitMultiNavigators(
  const ModelBox: TBox3d;
  const HomeCameraPos, HomeCameraDir, HomeCameraUp: TVector3Single;
  const CameraPreferredHeight, CameraRadius: Single);
begin
 { Init all navigators }
 TMatrixExaminer(Navigators[nkExaminer]).Init(ModelBox);
 TMatrixWalker  (Navigators[nkWalker  ]).Init(
   HomeCameraPos, HomeCameraDir, HomeCameraUp,
   CameraPreferredHeight, CameraRadius);
end;

function NavigatorKind: TNavigatorKind;
begin
 Result := FNavigatorKind;
end;

procedure SetNavigatorKind(glwin: TGLWindowNavigated; Kind: TNavigatorKind);
begin
 SetNavigatorKindInternal(glwin, Kind);
 glwin.PostRedisplay;
 { wywolaj EventResize zeby dostosowal zNear naszego projection do
   aktualnego glw.Navigator }
 glwin.EventResize;
end;

{$I MacChangeEnum.inc}

procedure ChangeNavigatorKind(glwin: TGLWindowNavigated; Change: integer);
begin
 {$define CHANGE_ENUM_TYPE := TNavigatorKind}
 {$define CHANGE_ENUM_NAME := NavigatorKind}
 {$define CHANGE_ENUM_CHANGE := Change}
 SetNavigatorKind(glwin, CHANGE_ENUM);
end;

{$I MacArrayPos.inc}
{$define ARRAY_POS_FUNCTION_NAME := StrToNavigatorKind}
{$define ARRAY_POS_ARRAY_NAME := NavigatorNames}
{$define ARRAY_POS_INDEX_TYPE := TNavigatorKind}
IMPLEMENT_ARRAY_POS_CASE_CHECKED

function MatrixWalker: TMatrixWalker;
begin
 Result := TMatrixWalker(Navigators[nkWalker]);
end;

  procedure OptionProc(OptionNum: Integer; HasArgument: boolean;
    const Argument: string; const SeparateArgs: TSeparateArgs; Data: Pointer);
  begin
   Assert(OptionNum = 0);
   FNavigatorKind := StrToNavigatorKind(Argument, true);
  end;

procedure MultiNavigatorsParseParameters;
const
  Options: array[0..0]of TOption =
  ((Short:#0; Long:'navigation'; Argument: oaRequired));
begin
 ParseParameters(Options, OptionProc, nil, true);
end;

{ unit init/fini ------------------------------------------------------------ }

procedure Fini;
var nk: TNavigatorKind;
begin
 for nk := Low(nk) to High(nk) do
  if NavigatorCreated[nk] then
   FreeAndNil(Navigators[nk]);
end;

finalization
 Fini;
end.
