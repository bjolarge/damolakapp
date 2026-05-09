import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { InjectRepository } from '@nestjs/typeorm';
import { Product } from './entities/product.entity';
import { Repository } from 'typeorm';

@Injectable()
export class ProductService {
  constructor( 
    @InjectRepository(Product)
  private readonly productRepository:Repository<Product>
  ){}
  create(createProductDto: CreateProductDto) {
    //return 'This action adds a new product';
     const product = this.productRepository.create(createProductDto);
    return this.productRepository.save(product);
  }

  findAll() {
    return this.productRepository.find()
  }

  async findOne(id: number) {
    const product =  await this.productRepository.findOne({where: {id}});
    if(!product){
      throw new NotFoundException(`Product with the given #${id} not found`);
    }
    return product;
  }

  async update(id: number, updateProductDto: UpdateProductDto) {
     const existingProduct= await this.productRepository.preload({
      id:+id,
      ...updateProductDto,
    });
    if(!existingProduct){
      throw new NotFoundException(`The ExistingProduct with the given ${id} not found`);
    }
    return this.productRepository.save(existingProduct);
  }

   async remove(id: number): Promise<Product | null> {
    const product = await this.productRepository.findOne({
      where: { id: id }, 
    });

    if (!product) {
      return null;
    }

    await this.productRepository.remove(product); 
    return product; 
  }
}
