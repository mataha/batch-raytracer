@if "%DEBUG%"=="" @echo off
::
:: Copyright (C) 2021  mataha <mataha@users.noreply.github.com>
::
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.
::
:: This program is distributed in the hope that it will be useful,
:: but WITHOUT ANY WARRANTY; without even the implied warranty of
:: MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
:: GNU General Public License for more details.
::
:: You should have received a copy of the GNU General Public License
:: along with this program.  If not, see <https://www.gnu.org/licenses/>.
::
@setlocal EnableDelayedExpansion EnableExtensions

set PROGRAM=%~n0
set VERSION=0.0.1-SNAPSHOT

set /a DEFAULT_WIDTH=256
set /a DEFAULT_HEIGHT=256
set /a DEFAULT_PROCESSES=2

goto :main


:: Shamelessly stolen from https://stackoverflow.com/a/5841587 (CC BY-SA 4.0)
:len (*string, *result)
    @setlocal EnableDelayedExpansion

    (set^ string=!%~1!)

    if defined string (
        set /a length=1
        for %%p in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
            if not "!string:~%%p,1!"=="" (
                set /a length+=%%p
                set "string=!string:~%%p!"
            )
        )
    ) else (
        set /a length=0
    )

    @endlocal & set "%~2=%length%" & goto :EOF

:add (*a, *b, *result)
    set /a %~3=(%~1 + %~2)

    goto :EOF

:sub (*a, *b, *result)
    set /a %~3=(%~1 - %~2)

    goto :EOF

:mul (*a, *b, *result)
    set /a %~3=(%~1 * %~2) / SCALE_FACTOR

    goto :EOF

:div (*a, *b, *result)
    set /a %~3=(%~1 * SCALE_FACTOR) / %~2

    goto :EOF

:mul2 (*number, *result)
    set /a "%~2=%~1 << 1"

    goto :EOF

:div2 (*number, *result)
    set /a "%~2=%~1 >> 1"

    goto :EOF

:abs (*number, *result)
    @setlocal EnableDelayedExpansion

    set number=!%~1!

    if %number% lss 0 (set /a result=-number) else (set /a result=number)

    @endlocal & set "%~2=%result%" & goto :EOF

:clamp (*number, *result)
    @setlocal EnableDelayedExpansion

    set number=!%~1!

    if %number% gtr %SCALE_FACTOR% (
        set result=%SCALE_FACTOR%
    ) else if %number% lss 0 (
        set result=0
    ) else (
        set result=%number%
    )

    @endlocal & set "%~2=%result%" & goto :EOF

:mod (*number, *result)
    set /a %~2=(%~1 % SCALE_FACTOR)

    goto :EOF

:truncate (*number, *result)
    set /a %~2=(%~1 / SCALE_FACTOR)

    goto :EOF

:sqrt (*number, *result)
    @setlocal EnableDelayedExpansion

    set /a number=%~1

    if %number% lss 0 (
        call :abs number "number"
        set imaginary=%IMAGINARY_UNIT%
    ) else (
        set imaginary=
    )

    :: Newton-Raphson's method for f(x_n) = x_n^2 - a, with x_0 = a/2:
    ::
    :: x_n+1 = x_n - f(x_n) / f'(x_n) =
    ::       = x_n - (x_n^2 - a) / (2 * x_n) = 
    ::       = 1/2 * (2 * x_n - (x_n - a / x_n)) =
    ::       = 1/2 * (x_n + a / x_n)
    ::
    call :div2 number "guess"

    for /l %%u in (1, 1, %NEWTON_RAPHSON_ITERATIONS%) do (
        if !guess! equ 0 goto :sqrt_result
        call :div  number guess "temp"
        call :add  temp   guess "temp"
        call :div2 temp  "guess"
    )

    :sqrt_result

    @endlocal & set "%~2=%guess%%imaginary%" & goto :EOF

:rsqrt (*number, *result)
    @setlocal EnableDelayedExpansion

    set /a number=%~1

    if %number% lss 0 (
        call :abs number "number"
        set imaginary=%IMAGINARY_UNIT%
    ) else (
        set imaginary=
    )

    call :div2 number "divided"

    :: Newton-Raphson's method for f(x_n) = 1/x_n^2 - a, with x_0 = 2/a:
    ::
    :: x_n+1 = x_n - f(x_n) / f'(x_n) = 
    ::       = x_n - (1 / x_n^2 - a) / (-2 / x_n^3) =
    ::       = x_n + (x_n - a * x_n^3) / 2 =
    ::       = x_n + 1/2 * x_n * (1 - a * x_n^2) = 
    ::       = x_n * (3/2 - a/2 * x_n^2)
    ::
    call :div TWO number "guess"

    for /l %%u in (1, 1, %NEWTON_RAPHSON_ITERATIONS%) do (
        call :mul guess guess   "temp"
        call :mul temp  divided "temp"
        call :sub THREE_HALVES temp "temp"
        call :mul temp  guess   "guess"
    )

    if defined imaginary set /a guess=-guess &:: i^2 = -i

    @endlocal & set "%~2=%guess%%imaginary%" & goto :EOF

:from_fp (*number, *result)
    @setlocal EnableDelayedExpansion

    set number=!%~1!

    if "%number:~-1%"=="%IMAGINARY_UNIT%" (
        set number=%number:~0,-1%
        set imaginary=%IMAGINARY_UNIT%
    ) else (
        set imaginary=
    )

    set /a integral=number / SCALE_FACTOR
    if %integral% equ 0 (
        if %number% geq 0 (
            set /a number+=SCALE_FACTOR
        ) else (
            set /a number-=SCALE_FACTOR
            set integral=-0
        )
    )

    set fractional=!number:~-%FRACTION_DIGITS%!

    set result=%integral%.%fractional%%imaginary%

    @endlocal & set "%~2=%result%" & goto :EOF

:to_fp (number, *result)
    @setlocal EnableDelayedExpansion

    set number=%~1

    for /f "usebackq tokens=1,2 delims=." %%i in ('%number%.0') do (
        set integral=%%i
        set fractional=%%j
    )

    set sign=!integral:~0,1!
    if not "%sign%"=="-" set sign=

    set fractional=!fractional:~0,%FRACTION_DIGITS%!
    call :len "fractional" "length"
    set /a padding_length=FRACTION_DIGITS - length & set padding=
    for /l %%u in (1, 1, %padding_length%) do set padding=0!padding!
    set fractional=%fractional%%padding%

    set /a result=integral * SCALE_FACTOR + %sign%fractional

    @endlocal & set "%~2=%result%" & goto :EOF

:print (*number) #io
    @setlocal

    call :from_fp "%~1" "result"

    echo:%result%

    @endlocal & goto :EOF

:vector3_new (x, y, z, *vector3)
    call :to_fp "%~1" "%~4.x"
    call :to_fp "%~2" "%~4.y"
    call :to_fp "%~3" "%~4.z"

    goto :EOF

:vector3_add (*a, *b, *result)
    call :add "%~1.x" "%~2.x" "%~3.x"
    call :add "%~1.y" "%~2.y" "%~3.y"
    call :add "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3_sub (*a, *b, *result)
    call :sub "%~1.x" "%~2.x" "%~3.x"
    call :sub "%~1.y" "%~2.y" "%~3.y"
    call :sub "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3_mul (*a, *b, *result)
    call :mul "%~1.x" "%~2.x" "%~3.x"
    call :mul "%~1.y" "%~2.y" "%~3.y"
    call :mul "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3_dot (*a, *b, *result)
    @setlocal

    call :mul "%~1.x" "%~2.x" "vector.x"
    call :mul "%~1.y" "%~2.y" "vector.y"
    call :mul "%~1.z" "%~2.z" "vector.z"

    call :add "vector.x" "vector.y" "result"
    call :add "vector.z" "result"   "result"

    @endlocal & set "%~3=%result%" & goto :EOF

:vector3_mulf (*vector3, *number, *result)
    call :mul "%~1.x" "%~2" "%~3.x"
    call :mul "%~1.y" "%~2" "%~3.y"
    call :mul "%~1.z" "%~2" "%~3.z"

    goto :EOF

:vector3_divf (*vector3, *number, *result)
    call :div "%~1.x" "%~2" "%~3.x"
    call :div "%~1.y" "%~2" "%~3.y"
    call :div "%~1.z" "%~2" "%~3.z"

    goto :EOF

:vector3_clamp (*vector3, *result)
    call :clamp "%~1.x" "%~2.x"
    call :clamp "%~1.y" "%~2.y"
    call :clamp "%~1.z" "%~2.z"

    goto :EOF

:vector3_sqrt (*vector3, *result)
    call :sqrt "%~1.x" "%~2.x"
    call :sqrt "%~1.y" "%~2.y"
    call :sqrt "%~1.z" "%~2.z"

    goto :EOF

:vector3_truncate (*vector3, *result)
    call :truncate "%~1.x" "%~2.x"
    call :truncate "%~1.y" "%~2.y"
    call :truncate "%~1.z" "%~2.z"

    goto :EOF

:vector3_unit (*vector3, *result)
    @setlocal

    call :vector3_dot "%~1" "%~1" "length_squared"
    call :rsqrt length_squared "length_reciprocal"
    call :vector3_mulf "%~1" length_reciprocal "result"

    @endlocal & set "%~2=%result%" & goto :EOF

:vector3_print (*vector3) #io
    @setlocal EnableDelayedExpansion

    call :from_fp "%~1.x" "x"
    call :from_fp "%~1.y" "y"
    call :from_fp "%~1.z" "z"

    echo:[%x%, %y%, %z%]

    @endlocal & goto :EOF

:sphere_intersect (@TODO)

:plane_intersect (@TODO)

:offset_origin (@TODO)

:light_contrib (@TODO)

:trace (@TODO *ray_origin, *ray_direction, depth, *color)

:error (message) #io
    >&2 echo:%~1

    goto :EOF

:init_constants ()
    set /a SCALE_FACTOR=1000
    call :len SCALE_FACTOR "FRACTION_DIGITS"
    set /a FRACTION_DIGITS-=1

    set /a NEWTON_RAPHSON_ITERATIONS=5
    set IMAGINARY_UNIT=i

    call :to_fp 1.5 THREE_HALVES
    call :to_fp 2   TWO

    goto :EOF

:: Loosely inspired by https://stackoverflow.com/a/8162578
:parse (args...)
    set "OPTIONS=--width:%DEFAULT_WIDTH% --height:%DEFAULT_HEIGHT%"
    set "OPTIONS=%OPTIONS% --processes:%DEFAULT_PROCESSES% --worker-index:"""
    set "OPTIONS=%OPTIONS% -h: --help: -?: --version:"

    for %%o in (%OPTIONS%) do for /f "tokens=1,* delims=:" %%i in ("%%o") do set "%%i=%%~j"

    set UNRECOGNIZED=

    :parse_loop
        if not "%~1"=="" (
            set "test=!OPTIONS:*%~1:=! "

            if "!test!"=="!OPTIONS! " (
                if defined UNRECOGNIZED (
                    set "UNRECOGNIZED=%UNRECOGNIZED% %~1"
                ) else (
                    set "UNRECOGNIZED=%~1"
                )
            ) else if "!test:~0,1!"==" " (
                set "%~1=true"
            ) else (
                set "%~1=%~2"
                shift /1
            )

            shift /1
            goto :parse_loop
        )

        set test=

    set OPTIONS=

    goto :EOF

:parse_parameters_as_ints ()
    set /a "IMAGE_WIDTH=%--width%"   2>nul || set /a IMAGE_WIDTH=DEFAULT_WIDTH
    set /a "IMAGE_HEIGHT=%--height%" 2>nul || set /a IMAGE_HEIGHT=DEFAULT_HEIGHT
    set /a "PROCESSES=%--processes%" 2>nul || set /a PROCESSES=DEFAULT_PROCESSES

    goto :EOF

:version
    echo:%VERSION%

    exit /b 0

:usage
    echo:Usage: %PROGRAM% [options...]
    echo:
    echo:    Does things, and then some other things.
    echo:
    echo:    Optional arguments:
    echo:      --width NUM       result image width (default: %DEFAULT_WIDTH%)
    echo:      --height NUM      result image height (default: %DEFAULT_HEIGHT%)
    echo:      --processes NUM   number of worker processes (default: %DEFAULT_PROCESSES%)
    echo:      -h, --help, -?    show this help message and exit
    echo:      --version         output version information and exit
    echo:
    echo:    Exit status:
    echo:      0                 successful program execution
    echo:      1                 this dialog was displayed
    echo:      2                 parse error

    exit /b 1

:unrecognized
    call :error "%PROGRAM%: error: unrecognized arguments: %UNRECOGNIZED%"
    call :error "Try '%PROGRAM% --help' for more information."

    exit /b 2

:main
    call :parse %*
    if defined UNRECOGNIZED goto :unrecognized

    if defined -h           goto :usage
    if defined --help       goto :usage
    if defined -?           goto :usage
    if defined --version    goto :version

    call :init_constants
    call :parse_parameters_as_ints

    :: random debugging stuff

    call :vector3_new 1 2 3 "a"
    call :vector3_new 1 2 3 "b"

    call :vector3_new 1.5 2.5 3.5 "q"
    call :vector3_print q

    call :vector3_dot a b "result"
    call :print result

    call :vector3_add a b "c"
    call :vector3_add c c "c"
    call :vector3_add c c "c"
    call :vector3_print "c"

    call :to_fp 2 "x"
    call :sqrt "x" "result"
    call :print result

    call :to_fp 3 "x"
    call :sqrt "x" "result"
    call :print result

    call :to_fp 123 "x"
    call :sqrt "x" "result"
    call :print result

@endlocal
