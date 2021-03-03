@if "%DEBUG%"=="" @echo off
::
:: Copyright (C) 2021  mataha
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

@set PROGRAM=%~n0
@set VERSION=0.0.1-SNAPSHOT

@goto :main


:: This could be probably relegated to IntelliJ IDEA batch utils, but... eh.
:append (*string, element, *result, separator)
    setlocal EnableDelayedExpansion

    if not "%~4"=="" (
        set "separator=%~4"
    ) else (
        set "separator=, "
    )

    set string=

    if not defined %~1 (
        set "string=%~2"
    ) else (
        set "string=!%~1!%separator%%~2"
    )

    endlocal & set "%~3=%string%" & goto :EOF

:: Shamelessly stolen from https://stackoverflow.com/a/5841587 (jeb, 2019)
:length (*string, *result)
    setlocal EnableDelayedExpansion

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

    endlocal & set "%~2=%length%" & goto :EOF

:add (*a, *b, *result)
    set /a "%~3=%~1 + %~2"

    goto :EOF

:sub (*a, *b, *result)
    set /a "%~3=%~1 - %~2"

    goto :EOF

:mul (*a, *b, *result)
    set /a "%~3=(%~1 * %~2) / SCALE_FACTOR"

    goto :EOF

:div (*a, *b, *result)
    set /a "%~3=(%~1 * SCALE_FACTOR) / %~2"

    goto :EOF

:mul2 (*number, *result)
    set /a "%~2=%~1 << 1"

    goto :EOF

:div2 (*number, *result)
    set /a "%~2=%~1 >> 1"

    goto :EOF

:abs (*number, *result)
    setlocal

    set /a number=%~1

    if %number% lss 0 (set /a result=-number) else (set /a result=number)

    endlocal & set "%~2=%result%" & goto :EOF

:clamp (*number, *result)
    setlocal

    set /a number=%~1

    if %number% gtr %SCALE_FACTOR% (
        set /a result=SCALE_FACTOR
    ) else if %number% lss 0 (
        set /a result=0
    ) else (
        set /a result=number
    )

    endlocal & set "%~2=%result%" & goto :EOF

:frac (*number, *result)
    setlocal

    set /a "result=%~1 %% SCALE_FACTOR"
    if %result% lss 0 call :add result SCALE_FACTOR "result"

    endlocal & set "%~2=%result%" & goto :EOF

:trunc (*number, *result)
    set /a "%~2=%~1 / SCALE_FACTOR"

    goto :EOF

:sqrt (*number, *result)
    setlocal

    set /a number=%~1 2>nul

    if %number% equ 0 endlocal & set "%~2=0" & goto :EOF

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
        call :div  number guess "temp"
        call :add  temp   guess "temp"
        call :div2 temp         "guess"
    )

    endlocal & set "%~2=%guess%%imaginary%" & goto :EOF

:rsqrt (*number, *result)
    setlocal

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
        call :mul guess        guess   "temp"
        call :mul temp         divided "temp"
        call :sub THREE_HALVES temp    "temp"
        call :mul temp         guess   "guess"
    )

    if defined imaginary if %guess% gtr 0 set /a guess=-guess

    endlocal & set "%~2=%guess%%imaginary%" & goto :EOF

:to_fp (number, *result)
    setlocal EnableDelayedExpansion

    set number=%~1

    set sign=!number:~0,1!
    if not "%sign%"=="-" set sign=

    if "%number:~-1%"=="%IMAGINARY_UNIT%" (
        set real=%number:~0,-1%
        if "!real!"=="%sign%" (
            set number=%sign%1
        ) else (
            set number=!real!
        )
        set imaginary=%IMAGINARY_UNIT%
    ) else (
        set imaginary=
    )

    for /f "usebackq tokens=1,2 delims=." %%i in ('%number%.0') do (
        set integral=%%i
        set fractional=%%j
    )

    set fractional=!fractional:~0,%FRACTION_DIGITS%!

    call :length fractional "length"
    set /a padding_length=FRACTION_DIGITS - length && set padding=
    for /l %%u in (1, 1, %padding_length%) do set padding=0!padding!

    set fractional=%fractional%%padding%

    :: A leading zero specifies an octal value: https://ss64.com/nt/set.html
    set /a leading=FRACTION_DIGITS - 1
    for /l %%u in (1, 1, %leading%) do (
        if "!fractional:~0,1!"=="0" set fractional=!fractional:~1!
    )

    set /a result=integral * SCALE_FACTOR + %sign%fractional

    endlocal & set "%~2=%result%%imaginary%" & goto :EOF

:to_string (*number, *result)
    setlocal EnableDelayedExpansion

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

    set result=%integral%.%fractional%

    endlocal & set "%~2=%result%%imaginary%" & goto :EOF

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
    setlocal

    call :mul "%~1.x" "%~2.x" "vector.x"
    call :mul "%~1.y" "%~2.y" "vector.y"
    call :mul "%~1.z" "%~2.z" "vector.z"

    call :add vector.x vector.y "result"
    call :add vector.z result   "result"

    endlocal & set "%~3=%result%" & goto :EOF

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

:vector3_trunc (*vector3, *result)
    call :trunc "%~1.x" "%~2.x"
    call :trunc "%~1.y" "%~2.y"
    call :trunc "%~1.z" "%~2.z"

    goto :EOF

:vector3_unit (*vector3, *result)
    setlocal

    call :vector3_dot "%~1" "%~1" "length_squared"
    call :rsqrt length_squared "length_reciprocal"
    call :vector3_mulf "%~1" length_reciprocal "result"

    :: Crude. Could this be abstracted further?
    set set_x=set "%~2.x=%result.x%"
    set set_y=set "%~2.y=%result.y%"
    set set_z=set "%~2.z=%result.z%"

    endlocal & %set_x% & %set_y% & %set_z% & goto :EOF

:vector3_to_string (*vector3, *string)
    setlocal

    call :to_string "%~1.x" "x"
    call :to_string "%~1.y" "y"
    call :to_string "%~1.z" "z"

    set result=[%x%, %y%, %z%]

    endlocal & set "%~2=%result%" & goto :EOF

:ray_new (*origin, *direction, *ray)
    set %~3.origin=%~1
    set %~3.direction=%~2

    goto :EOF

:ray_at (*ray, *parameter, *result)
    set origin=!%~1.origin!
    set direction=!%~1.direction!

    call :vector3_mulf %~2 direction "temp"
    call :vector3_add temp origin "result"
    goto :EOF

:hit_sphere (*ray_origin, *ray_direction, hit_t, *hit_point, *hit_normal)
    setlocal EnableDelayedExpansion

    :: from global? sphere_center sphere_radius

    set ray_origin=%~1

    call :vector3_sub ray_origin sphere_center "off_center"

    call :vector3_dot ray_direction ray_direction "a"
    call :vector3_dot ray_direction off_center "half_b"
    call :vector3_dot off_center off_center "off_center_squared"
    call :mul sphere_radius sphere_radius "sphere_radius_squared"
    call :sub off_center_squared sphere_radius_squared "c"

    call :mul half_b half_b half_b_squared
    call :mul a c ac
    call :sub half_b_squared ac discriminant

    if %discriminant% gtr 0 (
        call :sqrt discriminant root
        call :sub 0 half_b minus_half_b

        call :sub minus_half_b root t1
        call :div t1 a t1

        if !t1! gtr 0 (
            call :vector3_mulf ray_direction t1 t
            call :vector3_add ray_origin t hit_point
            call :vector3_sub hit_point sphere_center normal
            call :vector3_divf normal sphere_radius hit_normal

            
        )


    ) else (



    )



    endlocal & goto :EOF

:plane_intersect (@TODO)

:offset_origin (@TODO)

:light_contrib (@TODO)

:trace (@TODO *ray_origin, *ray_direction, depth, *color)

:error (message) #io
    >&2 echo:%PROGRAM%: error: %~1

    goto :EOF

:log (message) #io
    echo:[%DATE% %TIME%] %~1

    goto :EOF

:match (pattern, delimiters, !command, *result) -> errorlevel
    setlocal

    set match=

    for /f "usebackq tokens=1,* delims=%~2" %%i in (`%~3`) do (
        if "%~1"=="%%i" set match=%%j
    )

    if not "%match%"=="" (set /a code=0) else (set /a code=1)

    endlocal & set "%~4=%match%" & exit /b %code%

:: Loosely based on https://stackoverflow.com/a/8162578 (dbenham, 2011)
:parse (args...) -> errorlevel #global
    set meta=:
    set prefix=-

    :: Limitation: those are kept globally (used in help message)
    set /a DEFAULT_WIDTH=256
    set /a DEFAULT_HEIGHT=256
    set /a DEFAULT_PROCESSES=1

    :: Format: <name>:<type:(f)lag|(s)tring option|(n)umeric option>[:<default>]
    set "options=-h:f --help:f --version:f -t:f --test:f"
    set "options=%options% --width:n:%DEFAULT_WIDTH%"
    set "options=%options% --height:n:%DEFAULT_HEIGHT%"
    set "options=%options% --processes:n:%DEFAULT_PROCESSES%"
    set "options=%options% --worker-index:s:"""

    :: Warning: option keys are implicitly case insensitive! To get around this,
    :: we set metavariables here for later comparison in match().
    ::
    :: This could be enhanced further by placing help strings in metavariables,
    :: but then some options would be duplicated (e.g. '-h' and '--help'). TBD
    for %%o in (%options%) do for /f "tokens=1,2,* delims=:" %%i in ("%%o") do (
        if not "%%j"=="f" (
            set "%meta%%%i=option:%%~j"
        ) else (
            set "%meta%%%i=flag"
        )

        set "%%i=%%~k"
    )

    set INVALID=
    set UNRECOGNIZED=

    :parse_args
        if not "%~1"=="" (
            call :match "%meta%%~1" "=" "set %meta%%prefix%" "match"

            if "!match:~0,6!"=="option" (
                set "value=%~2"

                if "!value:~0,1!"=="%prefix%" (
                    call :append INVALID "%~1[=NULL]" "INVALID"
                ) else if "!match:~7,8!"=="s" (
                    set "%~1=!value!"
                ) else if "!match:~7,8!"=="n" (
                    set /a "number=value" 2>nul && (
                        if not "!number!"=="0" (set "%~1=!number!") else (call)
                    ) || (
                        if "!value!"=="" set value=NULL
                        call :append INVALID "%~1[=!value!]" "INVALID"
                    )
                ) else (
                    @rem I guess we've summoned an entity from the void itself.
                    call :error "unspecified parser error on token: !value!"
                    call :append INVALID "%~1[=?]" "INVALID"
                )

                if not "!value:~0,1!"=="%prefix%" shift /1

                set value=
            ) else if "!match!"=="flag" (
                set "%~1=true"
            ) else (
                call :append UNRECOGNIZED "%~1" "UNRECOGNIZED" " "
            )

            set match=
            shift /1
            goto :parse_args
        )

    if "%INVALID%%UNRECOGNIZED%"=="" (set /a code=0) else (set /a code=1)

    for /f "tokens=1,* delims==" %%m in ('set %meta%%prefix%') do set %%m=
    set "code=" & set "meta=" & set "prefix=" & set "options=" & exit /b %code%

:progress_bar_initialize (*progress_bar, width, text)
    call :abs "%~2" "%~1.width"
    set %~1.text=%~3

    goto :EOF

:progress_bar_display (*progress_bar, remaining, total) #io
    setlocal EnableDelayedExpansion

    :: Yes, these have to be bound, as we're calling length() on them later
    set /a remaining=%~2
    set /a total=%~3

    set /a done=((total - remaining) * %~1.width) / total
    set /a rest=%~1.width - done

    set bar=
    for /l %%u in (1, 1, %done%) do set "bar=!bar!="
    for /l %%u in (1, 1, %rest%) do set "bar=!bar! "

    set "text=" & if not "!%~1.text!"=="" (
        call :length total     "counter_width"
        call :length remaining "characters"
        set /a padding_length=counter_width - characters

        set counter=!remaining!
        for /l %%u in (1, 1, !padding_length!) do set counter= !counter!

        set text=!%~1.text!: !counter!
    )

    >con <nul set /p="[%bar%] %text%!CR!"

    endlocal & goto :EOF

:progress_bar_finalize (*progress_bar) #io
    >con <nul echo:

    set %~1.width=
    set %~1.text=

    goto :EOF

:setup () #global
    call :setup_colors
    call :setup_tui

    goto :EOF

:setup_colors () #global
    for /f "usebackq" %%c in (`echo prompt $E ^| cmd 2^>nul`) do set esc=%%c

    ver | find "Version 10.0" >nul 2>&1 && (
        set RED=%esc%[31m
        set GREEN=%esc%[32m
        set RESET=%esc%[0m
    ) || (
        set RED=
        set GREEN=
        set RESET=
    )

    set "esc=" & goto :EOF

:setup_tui () #global
    for /f "usebackq" %%c in (`copy /z "%~f0" nul 2^>nul`) do set CR=%%c

    goto :EOF

:test (*function (*number, *result), value, expected) -> errorlevel
    setlocal EnableDelayedExpansion

    call :to_fp %~2 "number"
    call :%~1 number "result"

    call :to_fp %~3 "number"
    if not "%number%"=="%result%" (
        set expected=%~3
        call :to_string result "actual"
        call :log "%~1(%~2): !actual! should be exactly !expected!"

        set /a code=1
    ) else (
        set /a code=0
    )

    endlocal & exit /b %code%

:test_runner
    set /a passed=failed=0

    for /f "usebackq tokens=* delims=:" %%y in (`findstr /b ":::" "%~f0"`) do (
        if not "%%~y"=="" call :test %%y && set /a passed+=1 || set /a failed+=1
    )

    set summary=
    set /a total=passed + failed

    if %total% neq 0 (
        set summary=%passed% passed, %failed% failed

        if %failed% equ 0 (
            set result=%GREEN%OK%RESET%
        ) else (
            set result=%RED%FAILED%RESET%
        )
    ) else (
        set result=N/A
    )

    >&2 echo:
    >&2 echo:Test result: %result%. %summary%

    exit /b -%failed%

:version
    echo:%VERSION%

    exit /b 0

:usage
    echo:Usage: %PROGRAM% [options...]
    echo:
    echo:    Runs a ray tracer with the specified parameters.
    echo:
    echo:    Optional arguments:
    echo:      --width=NUM       result image width (default: %DEFAULT_WIDTH%)
    echo:      --height=NUM      result image height (default: %DEFAULT_HEIGHT%)
    echo:      --processes=NUM   number of worker processes (default: %DEFAULT_PROCESSES%)
    echo:      -t, --test        execute a primitive test runner
    echo:      -h, --help        show this help message and exit
    echo:      --version         output version information and exit
    echo:
    echo:    Exit status:
    echo:      0                 successful program execution
    echo:      1                 this dialog was displayed
    echo:      2                 incorrect command line usage
    echo:
    echo:Example: %PROGRAM% ^>image.ppm --width=128 --height=128 --processes=1

    exit /b 1

:usage_error
    if defined INVALID      call :error "invalid values for options: %INVALID%"
    if defined UNRECOGNIZED call :error "unrecognized arguments: %UNRECOGNIZED%"
    >&2 echo:Try '%PROGRAM% --help' for more information.

    exit /b 2

:main
    call :parse %* || goto :usage_error

    if defined --help    goto :usage
    if defined -h        goto :usage
    if defined --version goto :version

        :: Setup module machinery
        call :setup

        :: Setup math machinery
        set /a SCALE_FACTOR=1000
        call :length SCALE_FACTOR FRACTION_DIGITS
        set /a FRACTION_DIGITS-=1

        set /a NEWTON_RAPHSON_ITERATIONS=5
        set IMAGINARY_UNIT=i

        :: Initialize math constants
        call :to_fp 1.5 THREE_HALVES
        call :to_fp 2   TWO

        call :to_fp -1  MINUS_ONE

    if defined --test    goto :test_runner
    if defined -t        goto :test_runner

    :: TODO: actual ray tracing

    echo:P3
    echo:%--width% %--height%
    echo:255

    call :to_fp 255.999 RGB_SCALING

    call :vector3_new 1 2 3 vector
    call :vector3_unit vector unit
    call :vector3_to_string unit string

    echo:%string%

    goto :EOF

    call :progress_bar_initialize progress_bar 28 "Scanlines remaining"

    set /a WIDTH=%--width% - 1
    call :to_fp %WIDTH% width_fp
    set /a HEIGHT=%--height% - 1
    call :to_fp %HEIGHT% height_fp

    call :vector3_new 0 0 0 origin

    for /l %%j in (%HEIGHT%, -1, 0) do (
        call :progress_bar_display progress_bar %%j HEIGHT
        for /l %%i in (0, 1, %WIDTH%) do (
            call :to_fp %%i x
            call :div x width_fp color.x

            call :to_fp %%j y
            call :div y height_fp color.y

            call :to_fp 0.25 color.z

            call :vector3_mulf color RGB_SCALING color
            call :vector3_trunc color color

            echo:!color.x! !color.y! !color.z!
        )
    )

    call :progress_bar_finalize progress_bar

@endlocal & @exit /b 0

:: Rust-style test suite (picked up by the test runner automatically)
::
::  function   argument        expected
::
::: abs        0               0
::: abs        1               1
::: abs        -1              1
::: clamp      0               0
::: clamp      0.5             0.5
::: clamp      1               1
::: clamp      2               1
::: clamp      -1              0
::: frac       0               0
::: frac       1.5             0.5
::: frac       -2.7            0.3
::: sqrt       0               0
::: sqrt       2               1.414
::: sqrt       3               1.732
::: sqrt       255             15.978
::: sqrt       -1              i
::: rsqrt      2               0.707
::: rsqrt      255             0.045
::: rsqrt      -1              -i
::: trunc      !SCALE_FACTOR!  1
