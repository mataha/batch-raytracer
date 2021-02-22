@if "%DEBUG%"=="" @echo off
@setlocal DisableDelayedExpansion EnableExtensions

set SCALE_FACTOR=10000
set FRAC_DIGITS=4
set IMAGINARY_UNIT=i
set /a NEWTON_ITERATIONS=5

call :to_fp 1.5 "THREE_HALVES"

:: random debugging stuff

call :vector3_fp 1 2 3 "a"
call :vector3_fp 1 2 3 "b"

call :vector3_dot a b "result"
call :print result

call :vector3_add a b "c"
call :vector3_add c c "c"
call :vector3_add c c "c"
call :vector3_print "c"

call :to_fp 2 "qqqq"
call :print qqqq
call :sqrt qqqq "result"
call :print result

call :to_fp 3 "qqqq"
call :print qqqq
call :sqrt qqqq "result"
call :print result

call :to_fp -3 "qqqq"
call :print qqqq
call :sqrt qqqq "result"
call :print result

call :to_fp 3 "qqqq"
call :print qqqq
call :rsqrt qqqq "result"
call :print result

call :to_fp -3 "qqqq"
call :print qqqq
call :rsqrt qqqq "result"
call :print result

:: TODO main

goto :EOF

:: Shamelessly stolen from https://stackoverflow.com/a/5841587
:len (*string, *result)
    @setlocal EnableDelayedExpansion

    (set^ string=!%~1!)

    if defined string (
        set /a length=1
        for %%p in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
            if not "!string:~%%p,1!"=="" (
                set /a length+=%%p
                set string=!string:~%%p!
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

:mul2 (*number, *result)
    set /a "%~2=%~1 << 1"

    goto :EOF

:div (*a, *b, *result)
    set /a %~3=(%~1 * SCALE_FACTOR) / %~2

    goto :EOF

:div2 (*number, *result)
    set /a "%~2=%~1 >> 1"

    goto :EOF

:div10 (*number, *result)
    call :div %~1 10 %~3

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

    :: Newton's method for x = sqrt(a): f(x) = x^2 - a; x_0 = a/2; n = 5:
    ::
    :: a       number
    :: n       iteration
    :: x_0     initial guess
    :: x_n+1   next guess
    ::
    :: x_n+1 = x_n - f(x_n) / f'(x_n) =
    ::       = x_n - (x_n^2 - a) / (2 * x_n) = 
    ::       = 1/2 * (2 * x_n - (x_n - a / x_n)) =
    ::       = 1/2 * (x_n + a / x_n)
    ::
    call :div2 number "guess"

    for /l %%u in (1, 1, %NEWTON_ITERATIONS%) do (
        if !guess! equ 0 goto :sqrt_result
        call :div  number guess "temp"
        call :add  temp   guess "temp"
        call :div2 temp         "guess"
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

    :: Newton's method for x = 1/sqrt(a): f(x) = 1/x^2 - a; x_0 = 2/a; n = 5:
    ::
    :: a       number
    :: n       iteration
    :: x_0     initial guess
    :: x_n+1   next guess
    ::
    :: x_n+1 = x_n - f(x_n) / f'(x_n) = 
    ::       = x_n - (1 / x_n^2 - a) / (-2 / x_n^3) =
    ::       = x_n + (x_n - a * x_n^3 / 2) =
    ::       = x_n + 1/2 * x_n * (1 - a * x_n^2) = 
    ::       = x_n * (3/2 - a * x_n^2 / 2)
    ::
    call :div SCALE_FACTOR number "guess"
    call :div2 number "divided"

    for /l %%u in (1, 1, %NEWTON_ITERATIONS%) do (
        call :mul guess guess   "temp"
        call :mul temp  divided "temp"
        call :sub THREE_HALVES temp "temp"
        call :mul temp  guess   "guess"
    )

    if defined imaginary set /a guess=-guess &:: i^2 = -1

    @endlocal & set "%~2=%guess%%imaginary%" & goto :EOF

:from_fp (*number, *result)
    @setlocal EnableDelayedExpansion

    set number=!%~1!

    :: Complex number support, purely for fun (only sqrt()/rsqrt() can return
    :: these, so there is no point in implementing similar checks in to_fp())
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

    set fractional=!number:~-%FRAC_DIGITS%!

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

    set fractional=!fractional:~0,%FRAC_DIGITS%!
    call :len "fractional" "length"
    set /a padding_length=FRAC_DIGITS - length & set padding=
    for /l %%u in (1, 1, %padding_length%) do set padding=0!padding!
    set fractional=%fractional%%padding%

    set /a result=integral * SCALE_FACTOR + %sign%fractional

    @endlocal & set "%~2=%result%" & goto :EOF

:print (*number)
    @setlocal

    call :from_fp "%~1" "result"

    echo:%result%

    @endlocal & goto :EOF

:vector3_fp (x, y, z, *vector3)
    set /a %~4.x=%~1 * SCALE_FACTOR
    set /a %~4.y=%~2 * SCALE_FACTOR
    set /a %~4.z=%~3 * SCALE_FACTOR

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

:vector3_dot (*a, *b, *result)
    @setlocal

    call :mul "%~1.x" "%~2.x" "vector.x"
    call :mul "%~1.y" "%~2.y" "vector.y"
    call :mul "%~1.z" "%~2.z" "vector.z"

    call :add "vector.x" "vector.y" "result"
    call :add "vector.z" "result"   "result"

    @endlocal & set "%~3=%result%" & goto :EOF

:vector3_truncate (*vector3, *result)
    call :truncate "%~1.x" "%~2.x"
    call :truncate "%~1.y" "%~2.y"
    call :truncate "%~1.z" "%~2.z"

    goto :EOF

:vector3_sqrt (*vector3, *result)
    call :sqrt "%~1.x" "%~2.x"
    call :sqrt "%~1.y" "%~2.y"
    call :sqrt "%~1.z" "%~2.z"

    goto :EOF

:vector3_normalize (*vector3, *result)
    @setlocal

    call :vector3_dot "%~1" "%~1" "length_squared"
    call :rsqrt length_squared "length_reciprocal"
    call :vector3_mulf "%~1" length_reciprocal "result"

    @endlocal & set "%~2=%result%" & goto :EOF

:vector3_print (*vector3)
    @setlocal EnableDelayedExpansion

    call :from_fp "%~1.x" "x"
    call :from_fp "%~1.y" "y"
    call :from_fp "%~1.z" "z"

    echo:[%x%, %y%, %z%]

    @endlocal & goto :EOF

@endlocal
