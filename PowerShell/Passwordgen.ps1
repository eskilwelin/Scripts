function New-RandomPassword {
    param([int]$Length = 16)

    $chars = @{
        Upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'      # No I/1/O/0 for clarity 
        Lower = 'abcdefghijklmnopqrstuvwxyz'
        Number = '23456789'
        Symbol = '!@#$%^&*-_=+'


    }
}