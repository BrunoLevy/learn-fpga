#include <femtorv32.h>
#include <femtoGL.h>

#include <bb_max7219_text.h>


void test5(void){
//    GL_set_font(&Font8x8);     

    BB_MAX7219_tty_init();
    int i=10;
    while(i--) {
        printf("%d: The quick brown fox jumped over the lazy dog!\n",i);
    }
}
/*
void test4(void)
{
    uint8_t cargo = 0x5a;
    
    //gpio_init(); //already called at the start of main


    printf("BITBANG SPI\n");
    
    bitbang_matrix_init();

    for (int i=0; i<4; i++)
    {
    bitbang_matrix(1, 0x55);
    bitbang_matrix(2, 0xaa);
    bitbang_matrix(3, 0x55);
    bitbang_matrix(4, 0xaa);
    bitbang_matrix(5, 0x55);
    bitbang_matrix(6, 0xaa);
    bitbang_matrix(7, 0x55);
    bitbang_matrix(8, 0xaa);
     
    delay(500);  
    bitbang_matrix(1, 0xaa);
    bitbang_matrix(2, 0x55);
    bitbang_matrix(3, 0xaa);
    bitbang_matrix(4, 0x55);
    bitbang_matrix(5, 0xaa);
    bitbang_matrix(6, 0x55);
    bitbang_matrix(7, 0xaa);
    bitbang_matrix(8, 0x55);
    delay(500);
    }

    bitbang_matrix(1, 0xaa & 0x01);
    bitbang_matrix(2, 0x55 & 0x03);
    bitbang_matrix(3, 0xaa & 0x07);
    bitbang_matrix(4, 0x55 & 0x0f);
    bitbang_matrix(5, 0xaa & 0x1f);
    bitbang_matrix(6, 0x55 & 0x3f);
    bitbang_matrix(7, 0xaa & 0x7f);
    bitbang_matrix(8, 0x55 & 0xff);
    
    
    //gpio_set_pin(GPIO_SS, GPIO_HI);
    printf("BITBANG SPI END\n");
}
*/
/*
void test3(void)
{
    uint8_t cargo = 0x5a;
    
    //gpio_init();

 #define BB_CLKusDELAY 10 //uS delay
    printf("BITBANG SPI\n");
    
    bitbang_spi_setup(GPIO_SS, GPIO_MOSI, IGNORE_PIN, GPIO_SCK, BB_CLKusDELAY);
    gpio_set_pin(GPIO_SS, GPIO_LO);                 
    microwait(BB_CLKusDELAY);
    
    (void)bitbang_spi_xfer8(cargo);
    gpio_set_pin(GPIO_SS, GPIO_HI);
    printf("BITBANG SPI END\n");
}

void test2(void)
{
    uint32_t t; 
    //gpio_init();
    gpio_set_all_modes(0x01);
    gpio_set_all_modes(0x02);
    gpio_set_all_modes(0x03);
    gpio_set_all_modes(0x04);
    gpio_set_all_modes(0x05);
    gpio_set_all_modes(0x06);
    gpio_set_all_modes(0x07);
    gpio_set_all_pins(0x00);
    gpio_set_all_pins(0x01);
    gpio_set_all_pins(0x02);
    gpio_set_all_pins(0x03);
    gpio_set_all_pins(0x04);
    gpio_set_all_pins(0x05);
    gpio_set_all_pins(0x06);
    gpio_set_all_pins(0x07);
    //milliwait(10);
    gpio_set_all_modes(0x06);  //input on least significant
    //milliwait(10);
    t = gpio_get_all_pins();
    printf("%d\n", t);
    t = gpio_get_all_pins();
    printf("%d\n", t);
    t = gpio_get_all_pins();
    printf("%d\n", t);

    //delay(1);

}

void test1(void)
{

   //gpio_init();//case for making this a cpp library
   show("Init");
   printf("get:%x\n", gpio_get_all_pins());
GL_set_font(&Font8x16); //required for make compact_gpio.hex to link
//   GL_tty_init(GL_MODE_OLED); 

   gpio_set_pin_mode(GPIO_SS, GPIO_MODE_OUTPUT);
   show("Sm");
   gpio_set_pin(GPIO_SS,GPIO_HI);
   show("S1");

   gpio_set_pin_mode(GPIO_SCK, GPIO_MODE_OUTPUT);
   show("Km");
   gpio_set_pin(GPIO_SCK,GPIO_LO);
   show("K0");
   
   gpio_set_pin_mode(GPIO_MOSI, GPIO_MODE_OUTPUT);
   show("Om");
   gpio_set_pin(GPIO_MOSI,GPIO_LO);
   show("O0");
   
   digitalWrite(GPIO_MOSI, GPIO_LO);
   delay(1);
   for (int j = 0; j<10; j++) {
      digitalWrite(GPIO_SCK, GPIO_HI);
      delay(1);
      digitalWrite(GPIO_SCK, GPIO_LO);
      delay(1);
   }
}
*/
void dummy_linkme(void)
{
   GL_set_font(&Font8x16); //required for make compact_gpio.hex to link    
}

int main()
{
   gpio_init();
   test5(); 
   exit(0);
}
