# ------------------------------------------------------------
# Program Name : rsa_3.s
# Author       : Corey Dyson, Ziyu Lin, Joseph Cottone
# Date         : 5/4/2025
# Purpose      : Implements RSA key generation, encryption, and decryption in ARM Assembly.
#                Allows user to generate keys (p, q, e, d), encrypt plaintext, and decrypt ciphertext.
#
# Functions    :
#   - generate_keys: Handles key generation, including modulus and totient calculation
#   - isPrime      : Checks whether a number is prime
#   - gcd          : Computes the greatest common divisor of two numbers
#   - cpubexp      : Prompts for and validates public exponent e
#   - cprivexp     : Computes private exponent d
#   - PromptForP   : Prompts user for valid prime p
#   - PromptForQ   : Prompts user for valid prime q
#   - modulo       : Computes n = p * q
#   - computePhi   : Computes phi(n) = (p - 1)(q - 1)
#   - encrypt_message: Encrypts a string using RSA and writes to a file
#   - decrypt_message: Decrypts encrypted integers back into a string
#   - pow          : Performs modular exponentiation c = m^e mod n
#
# Inputs       : User input via scanf for primes p, q, exponent e, and plaintext message
# Outputs      : Public/private keys printed to console, ciphertext to file, decrypted plaintext to file
# ------------------------------------------------------------

.text
.global generate_keys
.global encrypt_message
.global decrypt_message
.global menu_text
.global scan_format
.global menu_choice
.global main

.extern printf
.extern scanf
.extern fopen
.extern fclose
.extern fprintf
.extern fscanf
.extern fflush

.data
prompt_p: .asciz "Enter prime number p (p < 50): "
prompt_q: .asciz "Enter prime number q (q < 50): "
prompt_e: .asciz "Enter public exponent e (1 < e < phi(n), and gcd(e, phi(n)) = 1): "
scan_format: .asciz "%d"
scan_string_format: .asciz "%s"
p: .word 0
q: .word 0
e: .word 0
d: .word 0
not_prime: .asciz "\The number is not a prime. Please enter again.\n"
is_prime:    .asciz "\The number is a prime.\n"
msg_pubkey: .asciz "Public Key (n, e) = (%d, %d)\n"
msg_n: .asciz "Modulus n = %d\n"
msg_phi: .asciz "Totient phi(n) = %d\n"
msg_e: .asciz "Public exponent e = %d\n"
invalid_e_msg: .asciz "Invalid e. Must satisfy: 1 < e < phi and gcd(e, phi) = 1.\n"
msg_d: .asciz "Private exponent d = %d\n"
n_val: .word 0
e_val: .word 0
format_char: .asciz "%c"
d_val:       .word  0


debug_e: .asciz "Debug Before cprivexp: e = %d, phi = %d\n"
trying_x: .asciz "Trying x = %d\n"

menu_text: .asciz "\nSelect an option:\n1 - Generate Public and Private Keys\n2 - Encrypt a Message\n3 - Decrypt a Message\n4 - Exit\n\n"
menu_choice: .word 0

msg_input_plaintext: .asciz "Enter a plaintext message (no spaces): "
plaintext: .space 256
format_int: .asciz "%d "
file_encrypted: .asciz "encrypted.txt"
file_plaintext: .asciz "plaintext.txt"
mode_write: .asciz "w"
mode_read: .asciz "r"
msg_char:   .asciz "Char: %c\n"
msg_ascii:  .asciz "ASCII: %d\n"
msg_enc:    .asciz "Encrypted: %d\n"



# End Main

/* ------------------------------------ */
/* Generate Keys Main Function */
.text
generate_keys:
    # Program Dictionary
    # r4 - store p in r4
    # r5 - store q in r5
    # r6 - store modulus n = p * q in r6
    # r7 - store phi(n) = (p-1) * (q-1) in r7
    # r8 - store e in r8
    # r9 - store d in r9
    
    SUB sp, sp, #28
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    STR r6, [sp, #12]
    STR r7, [sp, #16]
    STR r8, [sp, #20]
    STR r9, [sp, #24]
    
    # Prompt p and check if it is prime number
    BL PromptForP
    MOV r4, r0    // Save p in r4
        
    # Prompt q and check if it is prime number
    BL PromptForQ
    MOV r5, r0    // Save q in r5

    # Calculate modulo n = p * q; input r0 - p, r1 - q
    MOV r0, r4
    MOV r1, r5
    BL modulo
    MOV r6, r0    // save modulus n = p * q in r6

    # Calculate fi(n) = (p-1)(q-1); and store fi(n) in r7
    MOV r0, r4
    MOV r1, r5
    BL computePhi
    MOV r7, r0    // Save phi in r7
        
    # Compute public key component (e)
    MOV r0, r7    // Pass phi in r7 to the function
    BL cpubexp
    MOV r8, r0    // Save e in r8
    
    # Compute private key exponent
    MOV r0, r8        // r0 = e
        MOV r1, r7        // r1 = phi
    BL cprivexp
    MOV r9, r0    // Store d in r9
    LDR r0, =d_val            // << new >>
    STR r9, [r0]              // save d so decrypt_message can load it later

    # Store n and e permanently
    LDR r0, =n_val
        STR r6, [r0]

        LDR r0, =e_val
        STR r8, [r0]

    B generateKeys_Done
    
                    
    generateKeys_Done:
        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
        LDR r5, [sp, #8]
        LDR r6, [sp, #12]
        LDR r7, [sp, #16]
        LDR r8, [sp, #20]
        LDR r9, [sp, #24]
        ADD sp, sp, #28
        MOV pc, lr


/* ------------------------------------ */
/* Generate Keys Helper Functions */
.text
isPrime:
    # Function purpose: check if r0 is prime number
    # Input: r0 = number to check
    # returns r0 = 1 if prime, 0 otherwise

    # Program Dictionary
    # r4 - Store input number into r4
    # r5 - Divisor, which starts from 2
    # r6 - n / 2
    # r7 - flag number, assume it is not prime

    SUB sp, sp, #20
    STR lr, [sp, #0]
    STR r4, [sp, #4]
        STR r5, [sp, #8]
        STR r6, [sp, #12]
        STR r7, [sp, #16]
 
    MOV r4, r0    // Store input number into r4
    MOV r5, #2      // Divisor starts from 2
    MOV r6, r4, LSR #1   // r6 = n / 2
    MOV r7, #0    // Flag number, assume it is not prime
    
    CMP r4, #1
    BLE NotPrime    // If n <= 1, it is not prime
    
    checkPrimeLoop:
        CMP r5, r6
            BGT CheckDone   // If divisor > n/2, done

        MOV r0, r4
            MOV r1, r5
            BL __aeabi_idiv
            MOV r2, r0      // quotient
        MOV r10, r2
        MUL r2, r10, r5  // quotient * divisor
            SUB r2, r4, r2  // remainder = n - (q * d)
            CMP r2, #0
            BEQ NotPrime    // If divisible, not a prime

            ADD r5, r5, #1
            B checkPrimeLoop

    CheckDone:
        MOV r0, #1      // Is prime
            B Return_primecheck

    NotPrime:
            MOV r0, #0
        B Return_primecheck

    Return_primecheck:
        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
            LDR r5, [sp, #8]
            LDR r6, [sp, #12]
            LDR r7, [sp, #16]
        ADD sp, sp, #20
        MOV pc, lr

# End isPrime    

.text
gcd:
    # Function purpose: find the greatest common divisor of a and b
    # Input: r0 = a (e), r1 = b (phi)
        # returns r0 = gcd(a, b)

    # Function pseudo code:
    # int gcd(int a, int b) {
        #    while (b != 0) {
        #        int r = a % b;
        #        a = b;
        #        b = r;
        #    }
        # return a;
    # }

    # Program Dictionary
    # r4: store r0 in r4

    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    
    gcd_loop:
        CMP r1, #0
            BEQ gcd_done
    
        MOV r4, r0    // Store r0 in r4
        BL __aeabi_idiv       // r0 = a / b
        MOV r2, r0            // r2 = quotient = a / b
        MUL r3, r2, r1        // r3 = quotient * b
        SUB r0, r4, r3        // r0 = a - (quotient * b) = a % b

        MOV r5, r1            // r5 = old b
            MOV r1, r0            // new b = remainder
            MOV r0, r5            // new a = old b
        B gcd_loop
    
    gcd_done:
        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
        ADD sp, sp, #8
        MOV pc, lr
.data
# End gcd

.text
cprivexp:
    # Function purpose: compute private key exponent d
    # loop through x = 1, 2, ... until we find an integer d such that (1 + x * phi) MOD e == 0. Then d = (1 + x * phi) / e
    # Input: r0 = e, r1 = phi
    # returns d in r0

    # Program Dictionary
        # r4 = Save e
        # r5 = Save phi
    # r6 = temp numerator
    # r7 = temp remainder
    # r8 = temp quotient
    # r9 = Save x counter

    SUB sp, sp, #28
        STR lr, [sp, #0]
        STR r4, [sp, #4]   // Save e
        STR r5, [sp, #8]   // Save phi
        STR r6, [sp, #12]  // temp numerator
        STR r7, [sp, #16]  // temp remainder
        STR r8, [sp, #20]  // temp quotient
        STR r9, [sp, #24]  // Save x counter

    # x starts from 1
    MOV r9, #1        // x counter
    MOV r4, r0        // Save e in r4
        MOV r5, r1        // Save phi in r5  
    LDR r3, =10000

    d_loop:
        CMP r9, r3
            BGE not_found       // If x >= 10000, give up

        MUL r6, r9, r5      // r6 = x * phi
            ADD r6, r6, #1      // r6 = 1 + x * phi

            MOV r0, r6          // numerator
            MOV r1, r4          // e
            BL __aeabi_idivmod  // Call IDIVMOD (returns quotient in r0, remainder in r1)

        MOV r8, r0          // save quotient
            MOV r7, r1          // save remainder

            CMP r7, #0
            BEQ d_found         // if remainder == 0, found d

        ADD r9, r9, #1
            B d_loop    

    
    d_found:
        // Recompute numerator = 1 + x * phi, in case the registers get weird
            MUL r6, r9, r5
           ADD r6, r6, #1

            MOV r0, r6      // numerator = 1+x*phi
            MOV r1, r4      // e
            BL __aeabi_idiv // final division to get d
        MOV r4, r0

        # Print d
            LDR r0, =msg_d
            MOV r1, r4
            BL printf
        
        MOV r0, r4
        B Return_cprivexp
        
    Return_cprivexp:

        LDR lr, [sp, #0]
            LDR r4, [sp, #4]
            LDR r5, [sp, #8]
            LDR r6, [sp, #12]
            LDR r7, [sp, #16]
            LDR r8, [sp, #20]
        LDR r9, [sp, #24]
            ADD sp, sp, #28
            MOV pc, lr

    not_found:
            MOV r0, #-1        // return -1 if not found
        B Return_cprivexp

# End cprivexp

.text
cpubexp:
    # Function purpose: compute public key component
    # Prompt for e, validate e
    # Input: r0 = phi
        # Output: r0 = valid e

    SUB sp, sp, #12
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    STR r5, [sp, #8]
    
    MOV r4, r0    // Save phi in r4

    PromptE:
        LDR r0, =prompt_e
            BL printf
            LDR r0, =scan_format
            LDR r1, =e
            BL scanf

        # Store e in r5
        LDR r5, =e
        LDR r5, [r5]

        LDR r0, =msg_e
            MOV r1, r5
            BL printf

        # Check: if e <= 1
        CMP r5, #1
        BLE InvalidE
        
        # Check: if e >= phi
        CMP r5, r4
        BGE InvalidE

        # Check: if gcd(e, phi) == 1
        MOV r0, r5      // r0 = e
        MOV r1, r4    // r1 = phi
        BL gcd
        CMP r0, #1
        BNE InvalidE
        
        B Return_cpubexp

    InvalidE:
        LDR r0, =invalid_e_msg
        BL printf
        B PromptE    
    
    Return_cpubexp:
        # Valid e, return in r
        LDR r0, =e    // load address of e
            LDR r0, [r0]  // load value of e into r0

        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
        LDR r5, [sp, #8]
        ADD sp, sp, #12
        MOV pc, lr

# End cpubexp

.text
PromptForP:
    # Function Purpose: Prompt for p and validate if it is prime
    # Input: no inputs
    # Output: r0 - p
    
    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]

    PromptP:
        # Prompt and read p
        LDR r0, =prompt_p
        BL printf
        LDR r0, =scan_format
        LDR r1, =p
        BL scanf
        
        # Store p in r4
        LDR r4, =p
        LDR r4, [r4]

        # Load p into r0 and check for prime
        MOV r0, r4
        BL isPrime
    
        # If it is not prime, prompt again for p
        CMP r0, #1
            BNE NotPrimeP

        B Return_PromptForP
    
    NotPrimeP:
           LDR r0, =not_prime
            BL printf
            B PromptP
    
    Return_PromptForP:
        LDR r0, =p
        LDR r0, [r0]

        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
        ADD sp, sp, #8
        MOV pc, lr

# End PromptForP

.text
PromptForQ:
    # Function Purpose: Prompt for q and validate if it is prime
    # Input: no inputs
    # Output: r0 - q
    
    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]

    PromptQ:
        # Prompt and read q
            LDR r0, =prompt_q
            BL printf
            LDR r0, =scan_format
            LDR r1, =q
            BL scanf

        # Store q in r4
            LDR r4, =q
            LDR r4, [r4]

        # Load q into r0 and check for prime
            MOV r0, r4
            BL isPrime
        
        CMP r0, #1
            BNE NotPrimeQ

        # If prime, finish
            B Return_PromptForQ

    NotPrimeQ:
            LDR r0, =not_prime
            BL printf
            B PromptQ

    Return_PromptForQ:
        LDR r0, =q
        LDR r0, [r0]

        LDR lr, [sp, #0]
        LDR r4, [sp, #4]
        ADD sp, sp, #8
        MOV pc, lr
    
# End PromptForQ

.text
modulo:
    # Function Purpose: Calculate modulus n = p * q
    # Input: r0 - p, r1 - q    
    # Output: r0 - n
    
    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]
    
    MOV r10, r0
    MUL r0, r10, r1   // n = p * q, n is the public key
    MOV r4, r0    // save n in r4

    LDR r0, =msg_n
        MOV r1, r4
        BL printf
    
    MOV r0, r4
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    ADD sp, sp, #8
    MOV pc, lr
# End modulo

.text
computePhi:
    # Function Purpose: Calculate Phi
    # Input: r0 - p, r1 - q
    # output: r0 - phi
    
    SUB sp, sp, #8
    STR lr, [sp, #0]
    STR r4, [sp, #4]

    SUB r0, r0, #1    // p = p-1
    SUB r1, r1, #1  // q = q-1
    MUL r4, r0, r1    // fi(n) =  (p - 1)(q - 1); store fi(n) in r4
    
    LDR r0, =msg_phi
        MOV r1, r4
        BL printf
    
    MOV r0, r4
    LDR lr, [sp, #0]
    LDR r4, [sp, #4]
    ADD sp, sp, #8
    MOV pc, lr

# End computePhi



/* ------------------------------------ */
/* Encrypt Message */
.text
encrypt_message:
        PUSH {r4-r9, lr}     // Preserve volatile registers
    # Function purpose: main encrypt message function
    
    # Program Dictionary:
    # r4 - store n in r4
    # r5 - store e in r5 
    # r6 - store file handle in r6
    
    # SUB sp, sp, #4
    # STR lr, [sp, #0]
    
    # Load n and e back from memory
    LDR r0, =n_val
        LDR r4, [r0]

        LDR r0, =e_val
        LDR r5, [r0]

        LDR r0, =msg_n    // Debug: print n and e
        MOV r1, r4    // r4 = n
        BL printf

        LDR r0, =msg_e    // r5 = e
        MOV r1, r5
        BL printf

    LDR r0, =msg_input_plaintext
        BL printf

        LDR r1, =plaintext        // buffer to store input
        LDR r0, =scan_string_format  // format string "%s"
        BL scanf

        # LDR r0, =plaintext
        # MOV r1, r0              // Use r1 as modifiable pointer to plaintext
        # BL scanf


    LDR r0, =file_encrypted
        LDR r1, =mode_write
        BL fopen
        MOV r6, r0           // r6 = file handle

        // Load plaintext address into r1
        LDR r1, =plaintext

    encrypt_loop:
            LDRB r2, [r1], #1     // Load next byte, increment pointer
            CMP r2, #0
            BEQ encrypt_done      // End of string
        
            MOV r7, r2              // Preserve original ASCII value

            // Debug print: char and ASCII
            LDR r0, =msg_char
            MOV r1, r7
            BL printf

            LDR r0, =msg_ascii
            MOV r1, r7
            BL printf

            // Convert r2 to integer m and encrypt: c = m^e mod n
            MOV r0, r7            // m in r0
            MOV r1, r5            // e
            MOV r2, r4            // n
            BL pow                // result c in r0
        MOV r8, r0              // encrypted = r0 → r8
        
        // Debug print: Encrypted
            LDR r0, =msg_enc
            MOV r1, r8
            BL printf

        // Write to file: fprintf(r6, "%d ", r8)
        # MOV r0, r6              // r0 = file handle
        MOV r0, r4              // r0 = file handle
        LDR r1, =format_int     // r1 = "%d "
        MOV r2, r8              // r2 = encrypted int
        BL fprintf

            B encrypt_loop

    encrypt_done:
            MOV r0, r6    // Flush and close file
            BL fflush
            BL fclose

        POP {r4-r9, lr}      // Restore registers
            MOV pc, lr

/* ------------------------------------ */
/* Decrypt Message */
.text
decrypt_message:
        PUSH {r4-r9, lr}          // preserve caller‑saved regs

        SUB   sp, sp, #4          // 4‑byte scratch for fscanf value
        MOV   r8, sp              // r8 = &value

        /* Load modulus n (r4) and private exponent d (r5) */
        LDR   r0, =n_val
        LDR   r4, [r0]
        LDR   r0, =d_val          // d was saved in generate_keys
        LDR   r5, [r0]

        /* fopen("encrypted.txt", "r") */
        LDR   r0, =file_encrypted
        LDR   r1, =mode_read
        BL    fopen
        MOV   r7, r0              // r6 = infile handle

        /* fopen("plaintext.txt", "w") */
        LDR   r0, =file_plaintext
        LDR   r1, =mode_write
        BL    fopen
        MOV   r7, r0              // r7 = outfile handle

decrypt_loop:
        // fscanf(infile, "%d", &value) ; returns 1 on success
        MOV   r0, r6              // infile
        LDR   r1, =scan_format    // "%d"
        MOV   r2, r8              // &value
        BL    fscanf
        CMP   r0, #1
        BNE   decrypt_done        // EOF or read error → leave loop

        LDR   r0, [r8]            // r0 = ciphertext c
        MOV   r1, r5              // r1 = d
        MOV   r2, r4              // r2 = n
        BL    pow                 // r0 ← m = c^d mod n

        /* write plaintext char */
        MOV   r3, r0              // keep m (ASCII) in r3
        MOV   r0, r7              // outfile handle
        LDR   r1, =format_char    // "%c"
        MOV   r2, r3              // char value
        BL    fprintf
        B     decrypt_loop

decrypt_done:
        /* flush & close both files */
        MOV   r0, r7
        BL    fflush
        BL    fclose
        MOV   r0, r6
        BL    fclose

        ADD   sp, sp, #4          // drop scratch word
        POP   {r4-r9, lr}
        BX    lr
/* End decrypt_message */

.text
pow:
    PUSH {lr}

    MOV r3, #1        // result = 1
    MOV r4, r0        // current base = base
    MOV r5, r1        // current exponent = exponent

modexp_loop:
    CMP r5, #0
    BEQ modexp_done

    // if (exponent & 1)
    AND r6, r5, #1
    CMP r6, #0
    BEQ skip_multiply

    // result = (result * base) % mod
    MOV r10, r3
    MUL r3, r10, r4
    MOV r0, r3
    MOV r1, r2
    BL __aeabi_idiv
    MUL r6, r0, r2
    SUB r3, r3, r6

skip_multiply:
    // base = (base * base) % mod
    MOV r10, r4
    MUL r4, r4, r10   // Fixed: avoid Rd == Rm
    MOV r11, r4
    MUL r4, r11, r10   // Fully fixed: avoid Rd == Rm
    MOV r1, r2
    BL __aeabi_idiv
    MUL r6, r0, r2
    SUB r4, r4, r6

    // exponent >>= 1
    MOV r5, r5, LSR #1
    B modexp_loop

modexp_done:
    MOV r0, r3        // return result in r0
    POP {lr}
    BX lr
