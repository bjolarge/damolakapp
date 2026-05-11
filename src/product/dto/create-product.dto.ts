import { ApiProperty } from "@nestjs/swagger";
import { IsBoolean, IsNotEmpty, IsNumber, IsString } from "class-validator";

export class CreateProductDto {
    @ApiProperty({
    example: 'Laptop',
    description: 'Product name',
  })
    @IsNotEmpty()
    @IsString()
    productname!:string;
    
    @ApiProperty({
    example: '1',
    description: 'Product Quantity',
  })
    @IsNumber()
    @IsNotEmpty()
    @IsNotEmpty()
    productQuantity!:number
    
        
}
