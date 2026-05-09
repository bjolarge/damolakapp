import { Column, Entity, Index, PrimaryGeneratedColumn } from "typeorm";

@Entity('damosproduct')
export class Product {
    @Index()
    @PrimaryGeneratedColumn()
    id!:number;

    @Column()
    productname!:string;

    @Column()
    productQuantity!:number
    
}
