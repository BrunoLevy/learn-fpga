
/**
 * \brief Computes a simple raytracing image.
 * \param[in] tty_output if non-zero, displays the
 *  scene on the terminal using color ansi 
 *  sequences. Deactivate it for benchmarking.
 */
void tinyraytracer(int tty_output);


/**
 * \brief Displays a moving pattern on the OLED screen.
 */ 
void oled_test(void);

/**
 * \brief Displays a rotating RISCV logo on the OLED screen.
 */ 
void oled_riscv_logo(void);
