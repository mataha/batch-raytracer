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


::
:: batch-raytracer ~ string utilities
::..............................................................................

:contains (char_sequence, string) -> errorlevel
    setlocal EnableDelayedExpansion

    if "%~2"=="" if not "%~1"=="" endlocal & exit /b 1

    set string=%~2

    if not "!string:%~1=!"=="!string!" (set /a code=0) else (set /a code=1)

    endlocal & exit /b %code%

:join (*result, element, *string, separator)
    setlocal EnableDelayedExpansion

    if not "%~4"=="" (set "separator=%~4") else (set "separator=, ")

    set string=%~2

    if defined %~3 set string=!%~3!%separator%%string%

    endlocal & set "%~1=%string%" & goto :EOF

:: Shamelessly stolen from https://stackoverflow.com/a/5841587 (jeb, 2019)
:length (*result, *string)
    setlocal EnableDelayedExpansion

    (set^ string=!%~2!)

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

    endlocal & set "%~1=%length%" & goto :EOF

::
:: batch-raytracer ~ fixed-point number ~ initialization
::..............................................................................

:init_fp (precision) #global
    set SCALE_FACTOR=1
    for /l %%u in (1, 1, %~1) do set /a SCALE_FACTOR*=10

    call :length FRACTION_DIGITS SCALE_FACTOR
    set /a FRACTION_DIGITS-=1

    set /a NEWTON_RAPHSON_ITERATIONS=5
    set IMAGINARY_UNIT=i

    call :to_fp THREE_HALVES 1.5
    call :to_fp TWO          2

    goto :EOF

::
:: batch-raytracer ~ fixed-point number ~ operations and other utilities
::..............................................................................

:add (*result, *a, *b)
    set /a "%~1=%~2 + %~3"

    goto :EOF

:sub (*result, *a, *b)
    set /a "%~1=%~2 - %~3"

    goto :EOF

:mul (*result, *a, *b)
    set /a "%~1=(%~2 * %~3) / SCALE_FACTOR"

    goto :EOF

:div (*result, *a, *b)
    set /a "%~1=(%~2 * SCALE_FACTOR) / %~3"

    goto :EOF

:mul2 (*result, *number)
    set /a "%~1=%~2 << 1"

    goto :EOF

:div2 (*result, *number)
    set /a "%~1=%~2 >> 1"

    goto :EOF

:abs (*result, *number)
    setlocal

    set /a number=%~2

    if %number% lss 0 (set /a result=-number) else (set /a result=number)

    endlocal & set "%~1=%result%" & goto :EOF

:clamp (*result, *number)
    setlocal

    set /a number=%~2

    if %number% gtr %SCALE_FACTOR% (
        set /a result=SCALE_FACTOR
    ) else if %number% lss 0 (
        set /a result=0
    ) else (
        set /a result=number
    )

    endlocal & set "%~1=%result%" & goto :EOF

:frac (*result, *number)
    setlocal

    set /a "result=%~2 %% SCALE_FACTOR"
    if %result% lss 0 call :add result result SCALE_FACTOR

    endlocal & set "%~1=%result%" & goto :EOF

:trunc (*result, *number)
    set /a "%~1=%~2 / SCALE_FACTOR"

    goto :EOF

:sqrt (*result, *number)
    setlocal

    set /a number=%~2 2>nul

    if %number% equ 0 endlocal & set "%~1=0" & goto :EOF

    if %number% lss 0 (
        call :abs number number
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
    call :div2 guess number

    for /l %%u in (1, 1, %NEWTON_RAPHSON_ITERATIONS%) do (
        call :div  temp   number guess
        call :add  temp   temp   guess
        call :div2 guess  temp
    )

    endlocal & set "%~1=%guess%%imaginary%" & goto :EOF

:rsqrt (*result, *number)
    setlocal

    set /a number=%~2

    if %number% lss 0 (
        call :abs number number
        set imaginary=%IMAGINARY_UNIT%
    ) else (
        set imaginary=
    )

    call :div2 divided number

    :: Newton-Raphson's method for f(x_n) = 1/x_n^2 - a, with x_0 = 2/a:
    ::
    :: x_n+1 = x_n - f(x_n) / f'(x_n) = 
    ::       = x_n - (1 / x_n^2 - a) / (-2 / x_n^3) =
    ::       = x_n + (x_n - a * x_n^3) / 2 =
    ::       = x_n + 1/2 * x_n * (1 - a * x_n^2) = 
    ::       = x_n * (3/2 - a/2 * x_n^2)
    ::
    call :div guess TWO number

    for /l %%u in (1, 1, %NEWTON_RAPHSON_ITERATIONS%) do (
        call :mul temp  guess        guess
        call :mul temp  temp         divided
        call :sub temp  THREE_HALVES temp
        call :mul guess temp         guess
    )

    if defined imaginary if %guess% gtr 0 set /a guess=-guess

    endlocal & set "%~1=%guess%%imaginary%" & goto :EOF

:to_fp (*result, number)
    setlocal EnableDelayedExpansion

    set number=%~2

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

    call :length length fractional
    set /a padding_length=FRACTION_DIGITS - length && set padding=
    for /l %%u in (1, 1, %padding_length%) do set padding=0!padding!

    set fractional=%fractional%%padding%

    :: A leading zero specifies an octal value: https://ss64.com/nt/set.html
    set /a leading=FRACTION_DIGITS - 1
    for /l %%u in (1, 1, %leading%) do (
        if "!fractional:~0,1!"=="0" set fractional=!fractional:~1!
    )

    set /a result=integral * SCALE_FACTOR + %sign%fractional

    endlocal & set "%~1=%result%%imaginary%" & goto :EOF

:to_str (*result, *number)
    setlocal EnableDelayedExpansion

    set number=!%~2!

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

    endlocal & set "%~1=%result%%imaginary%" & goto :EOF

::
:: batch-raytracer ~ three-dimensional vector ~ operations and other utilities
::..............................................................................

:vector3d_new (*vector3d, x, y, z)
    call :to_fp "%~1.x" "%~2"
    call :to_fp "%~1.y" "%~3"
    call :to_fp "%~1.z" "%~4"

    goto :EOF

:vector3d_add (*result, *a, *b)
    call :add "%~1.x" "%~2.x" "%~3.x"
    call :add "%~1.y" "%~2.y" "%~3.y"
    call :add "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3d_sub (*result, *a, *b)
    call :sub "%~1.x" "%~2.x" "%~3.x"
    call :sub "%~1.y" "%~2.y" "%~3.y"
    call :sub "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3d_mul (*result, *a, *b)
    call :mul "%~1.x" "%~2.x" "%~3.x"
    call :mul "%~1.y" "%~2.y" "%~3.y"
    call :mul "%~1.z" "%~2.z" "%~3.z"

    goto :EOF

:vector3d_dot (*result, *a, *b)
    setlocal

    call :mul vector.x "%~2.x" "%~3.x"
    call :mul vector.y "%~2.y" "%~3.y"
    call :mul vector.z "%~2.z" "%~3.z"

    call :add result vector.x vector.y
    call :add result vector.z result

    endlocal & set "%~1=%result%" & goto :EOF

:vector3d_mulf (*result, *vector3d, *number)
    call :mul "%~1.x" "%~2.x" "%~3"
    call :mul "%~1.y" "%~2.y" "%~3"
    call :mul "%~1.z" "%~2.z" "%~3"

    goto :EOF

:vector3d_divf (*result, *vector3d, *number)
    call :div "%~1.x" "%~2.x" "%~3"
    call :div "%~1.y" "%~2.y" "%~3"
    call :div "%~1.z" "%~2.z" "%~3"

    goto :EOF

:vector3d_clamp (*result, *vector3d)
    call :clamp "%~1.x" "%~2.x"
    call :clamp "%~1.y" "%~2.y"
    call :clamp "%~1.z" "%~2.z"

    goto :EOF

:vector3d_sqrt (*result, *vector3d)
    call :sqrt "%~1.x" "%~2.x"
    call :sqrt "%~1.y" "%~2.y"
    call :sqrt "%~1.z" "%~2.z"

    goto :EOF

:vector3d_trunc (*result, *vector3d)
    call :trunc "%~1.x" "%~2.x"
    call :trunc "%~1.y" "%~2.y"
    call :trunc "%~1.z" "%~2.z"

    goto :EOF

:vector3d_unit (*result, *vector3d)
    setlocal EnableDelayedExpansion

    call :vector3d_dot  length_squared    "%~2" "%~2"
    call :rsqrt         length_reciprocal length_squared
    call :vector3d_mulf result            "%~2" length_reciprocal

    for %%c in (x y z) do set set_result_%%c=set "%~1.%%c=!result.%%c!"
    endlocal & %set_result_x% & %set_result_y% & %set_result_z% & goto :EOF

:vector3d_echo (*vector3d)
    setlocal EnableDelayedExpansion

    echo:!%~1.x! !%~1.y! !%~1.z!

    endlocal & goto :EOF

:vector3d_to_str (*result, *vector3d)
    setlocal

    call :to_str x_str "%~2.x"
    call :to_str y_str "%~2.y"
    call :to_str z_str "%~2.z"

    set result=[%x_str%, %y_str%, %z_str%]

    endlocal & set "%~1=%result%" & goto :EOF

::
:: batch-raytracer ~ actual ray tracing
::..............................................................................

:ray_new (*origin, *direction, *ray)
    set %~3.origin=%~1
    set %~3.direction=%~2

    goto :EOF

:ray_at (*ray, *parameter, *result)
    set origin=!%~1.origin!
    set direction=!%~1.direction!

    call :vector3d_mulf temp %~2 direction
    call :vector3d_add result temp origin
    goto :EOF

:hit_sphere (*ray_origin, *ray_direction, hit_t, *hit_point, *hit_normal)
    setlocal EnableDelayedExpansion

    :: from global? sphere_center sphere_radius

    set ray_origin=%~1

    call :vector3d_sub off_center ray_origin sphere_center

    call :vector3d_dot a      ray_direction ray_direction
    call :vector3d_dot half_b ray_direction off_center
    call :vector3d_dot off_center_squared off_center off_center
    call :mul sphere_radius_squared sphere_radius sphere_radius
    call :sub c off_center_squared sphere_radius_squared

    call :mul half_b_squared half_b half_b
    call :mul ac a c
    call :sub discriminant half_b_squared ac

    if %discriminant% gtr 0 (
        call :sqrt root discriminant
        call :sub minus_half_b 0 half_b

        call :sub t1 minus_half_b root
        call :div t1 t1 a

        if !t1! gtr 0 (
            call :vector3d_mulf t ray_direction t1
            call :vector3d_add hit_point ray_origin       t
            call :vector3d_sub normal    hit_point  sphere_center
            call :vector3d_divf hit_normal normal sphere_radius

            
        )


    ) else (



    )



    endlocal & goto :EOF

:plane_intersect (@TODO)

:offset_origin (@TODO)

:light_contrib (@TODO)

:trace (@TODO *ray_origin, *ray_direction, depth, *color)

::
:: batch-raytracer ~ logging
::..............................................................................

:error (message) #io
    >&2 echo:%PROGRAM%: error: %~1

    goto :EOF

:log (message) #io
    echo:%DATE% %TIME% %~1

    goto :EOF

::
:: batch-raytracer ~ command-line interface ~ initialization
::..............................................................................

:setup () #global
    call :setup_cli
    call :setup_colors

    goto :EOF

:setup_cli () #global
    for /f "usebackq" %%c in (`copy /z "%~f0" nul 2^>nul`) do set CR=%%c

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

::
:: batch-raytracer ~ command-line interface ~ option parsing
::..............................................................................

:match (*match, pattern, delimiters, ~command) -> errorlevel
    setlocal

    set match=

    for /f "usebackq tokens=1,* delims=%~3" %%i in (`%~4`) do (
        if "%~2"=="%%i" set match=%%j
    )

    if not "%match%"=="" (set /a code=0) else (set /a code=1)

    endlocal & set "%~1=%match%" & exit /b %code%

:: Loosely based on https://stackoverflow.com/a/8162578 (dbenham, 2011)
:parse (options, arguments, args...) -> errorlevel #global
    set meta=:
    set prefix=-

    :: Format: <name>:<type:(f)lag|(n)umeric option|(s)tring option>[:<default>]
    ::
    :: Restriction - numeric options can accept natural numbers only:
    ::
    ::  * zero is used to detect a specified variable name that is not defined
    ::    in the current environment (https://ss64.com/nt/set.html);
    ::  * negative numbers start with '-', and are thus treated as option keys.
    ::
    :: Thankfully, this is completely in-line with how we want to handle numeric
    :: options here.
    set options=%~1
    shift /1

    :: Warning: option keys are implicitly case insensitive! To get around this,
    :: we set metavariables here for later comparison in match().
    ::
    :: This could be enhanced further by placing help strings in metavariables,
    :: but then some options would be duplicated (e.g. '-h' and '--help'). TODO
    for %%o in (%options%) do for /f "tokens=1,2,* delims=:" %%i in ("%%o") do (
        if not "%%~j"=="f" (
            set "%meta%%%i=option:%%~j"
        ) else (
            set "%meta%%%i=flag"
        )

        set "%%i=%%~k"
    )

    :: TODO - support a non-zero number of positional arguments
    set /a arguments=%~1
    shift /1
    set /a position=1

    set INVALID=
    set UNRECOGNIZED=

    :parse_args
        if not "%~1"=="" (
            call :match match "%meta%%~1" "=" "set %meta%%prefix%"

            if "!match:~0,6!"=="option" (
                set "value=%~2"

                if "!value:~0,1!"=="%prefix%" (
                    call :join INVALID "%~1[=NULL]" INVALID
                ) else if "!match:~7,8!"=="s" (
                    set "%~1=!value!"
                ) else if "!match:~7,8!"=="n" (
                    set /a "number=value" 2>nul && (
                        if not "!number!"=="0" (set "%~1=!number!") else (call)
                    ) || (
                        if "!value!"=="" set value=NULL
                        call :join INVALID "%~1[=!value!]" INVALID
                    )
                ) else (
                    @rem I guess we've summoned an entity from the void itself.
                    call :error "unspecified parse error on token: !value!"
                    call :join INVALID "%~1[=?]" INVALID
                )

                if not "!value:~0,1!"=="%prefix%" shift /!position!

                set value=
            ) else if "!match!"=="flag" (
                set "%~1=true"
            ) else (
                call :join UNRECOGNIZED "%~1" UNRECOGNIZED " "
            )

            set match=
            shift /!position!
            goto :parse_args
        )

    :: Cleanup
    for /f "tokens=1,* delims==" %%m in ('set %meta%%prefix%') do set %%m=
    for %%v in (meta prefix options arguments position) do set %%v=

    if "%INVALID%%UNRECOGNIZED%"=="" (set /a code=0) else (set /a code=1)
    set "code=" & exit /b %code%

::
:: batch-raytracer ~ command-line interface ~ progress bar
::..............................................................................

:progress_bar_initialize (*progress_bar, *width, text, file)
    call :abs "%~1.width" "%~2"
    set "%~1.text=%~3"
    if not "%~4"=="" (set "%~1.file=%~4") else (set "%~1.file=con") &:: default

    goto :EOF

:progress_bar_display (*progress_bar, remaining, total) #io
    setlocal EnableDelayedExpansion

    set /a remaining=%~2
    set /a total=%~3

    set /a done=((total - remaining) * %~1.width) / total
    set /a rest=%~1.width - done

    set bar=
    for /l %%u in (1, 1, %done%) do set "bar=!bar!="
    for /l %%u in (1, 1, %rest%) do set "bar=!bar! "

    set "text=" & if not "!%~1.text!"=="" (
        call :length counter_width total
        call :length characters    remaining
        set /a padding_length=counter_width - characters

        set counter=!remaining!
        for /l %%u in (1, 1, !padding_length!) do set counter= !counter!

        set text=!%~1.text! !counter!
    )

    if not "!%~1.file!"=="" >"!%~1.file!" <nul set /p="[%bar%] %text%!CR!"

    endlocal & goto :EOF

:progress_bar_finalize (*progress_bar, text) #io
    setlocal EnableDelayedExpansion

    if not "!%~1.file!"=="" >"!%~1.file!" <nul echo:
    if not "%2"==""         >"!%~1.file!" <nul echo:%~2

    endlocal

    set %~1.width=
    set %~1.text=
    set %~1.file=

    goto :EOF

::
:: batch-raytracer ~ primitive unit testing framework
::..............................................................................

:test (:function (*number, *result), expected, arguments...) -> errorlevel
    setlocal EnableDelayedExpansion

    set args=
    set fp_args=

    :test_args
        if not "%~3"=="" (
            set arg=%~3
            call :contains "!arg:~0,1!" "-0123456789" || goto :break &@rem note

            call :join args !arg! args

            call :to_fp fp_arg !arg!
            call :join fp_args !fp_arg! fp_args " "

            shift /3
            goto :test_args
        )

        :break

    call :to_fp number "%~2"
    call :%~1   result %fp_args%

    if "%number%"=="%result%" (
        set /a code=0
    ) else (
        set /a code=1

        set expected=%~2
        call :to_str actual result

        call :log "%~0    %~1(%args%): !actual! should be exactly !expected!"
    )

    endlocal & exit /b %code%

:test_runner
    set "UT=::: "

    set /a passed=failed=0

    for /f "usebackq tokens=* delims=:" %%y in (`findstr /b "%UT%" "%~f0"`) do (
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

::
:: batch-raytracer ~ main flow
::..............................................................................

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
    if defined UNRECOGNIZED call :error "unrecognized options: %UNRECOGNIZED%"
    >&2 echo:Try '%PROGRAM% --help' for more information.

    exit /b 2

:main
    set /a DEFAULT_WIDTH=256
    set /a DEFAULT_HEIGHT=256
    set /a DEFAULT_PROCESSES=1

    set "OPTS=-h:f --help:f --version:f -t:f --test:f"
    set "OPTS=%OPTS% --width:n:%DEFAULT_WIDTH%"
    set "OPTS=%OPTS% --height:n:%DEFAULT_HEIGHT%"
    set "OPTS=%OPTS% --processes:n:%DEFAULT_PROCESSES%"
    set "OPTS=%OPTS% --worker-index:s:"""

    call :parse "%OPTS%" 0 %* || goto :usage_error

    if defined --help    goto :usage
    if defined -h        goto :usage
    if defined --version goto :version

    call :setup
    call :init_fp 3

    if defined --test    goto :test_runner
    if defined -t        goto :test_runner

    :: TODO: actual ray tracing

    echo:P3
    echo:%--width% %--height%
    echo:255

    ::goto :EOF

    call :to_fp RGB_SCALING 255.999

    call :progress_bar_initialize progress_bar 28 "Scanlines remaining:"

    set /a WIDTH=%--width% - 1
    call :to_fp width_fp %WIDTH%

    set /a HEIGHT=%--height% - 1
    call :to_fp height_fp %HEIGHT%

    call :vector3d_new origin 0 0 0

    for /l %%j in (%HEIGHT%, -1, 0) do (
        call :progress_bar_display progress_bar %%j HEIGHT
        for /l %%i in (0, 1, %WIDTH%) do (
            call :to_fp x %%i
            call :div color.x x width_fp

            call :to_fp y %%j
            call :div color.y y height_fp

            call :to_fp color.z 0.25

            call :vector3d_mulf color color RGB_SCALING
            call :vector3d_trunc color color

            call :vector3d_echo color
        )
    )

    call :progress_bar_finalize progress_bar "Done."

@endlocal & exit /b 0

::
:: batch-raytracer ~ test suite (Rust-style)
::..............................................................................
::
::  function   expected        arguments       notes
::
::: abs        0               0
::: abs        1               1
::: abs        1               -1
::: clamp      0               0
::: clamp      0.5             0.5
::: clamp      1               1
::: clamp      1               2
::: clamp      0               -1
::: frac       0               0
::: frac       0.5             1.5
::: frac       0.3             -2.7
::: sqrt       0               0
::: sqrt       1.414           2
::: sqrt       1.732           3
::: sqrt       15.978          255
::: sqrt       i               -1
::: rsqrt      0.707           2
::: rsqrt      0.045           255
::: rsqrt      -i              -1
::: trunc      1               !SCALE_FACTOR!  requires EnableDelayedExpansion
