
/**
 * \brief Computes a simple raytracing image.
 * \param[in] tty_output if non-zero, displays the
 *  scene on the terminal using color ansi 
 *  sequences. Deactivate it for benchmarking.
 * \details Original demo by Dimtry Sokolov.
 */
void tinyraytracer(int tty_output);

/**
 * mandelbrot set, using fixed point.
 */ 
void mandelbrot(void);

/**
 * \brief Displays a moving pattern on the OLED screen.
 */ 
void oled_test(void);

/**
 * \brief Displays a rotating RISCV logo on the OLED screen.
 */ 
void oled_riscv_logo(void);

/**
 * \brief Displays an animated Julia set on the OLED screen.
 * \details Demo by Sylvain Lefebvre.
 */ 
void oled_julia(void);

/**
 * \brief Displays and computes the decimals of pi.
 * \details By Fabrice Bellard.
 */ 
void pi(void);

