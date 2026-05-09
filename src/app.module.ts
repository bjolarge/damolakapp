import { Module, NestModule, RequestMethod } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import * as Joi from 'joi';
import { APP_GUARD } from '@nestjs/core';
import { NestMiddleware, Injectable } from '@nestjs/common';
import { MiddlewareConsumer } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { readFileSync } from 'fs';
import { join } from 'path';
import { ScheduleModule } from '@nestjs/schedule';
import { createModule } from 'create-nestjs-middleware-module'
//import { CsrfModule } from '@tekuconcept/nestjs-csrf'
import { ProductModule } from './product/product.module';
import session from 'express-session'
import cookieParser from 'cookie-parser'




require('dotenv').config();
//if production
const isProduction = process.env.NODE_ENV === 'production';

//this prevents CSRF attacks
const CookieParserModuleBase = createModule(() => {
  return cookieParser();
});

const SessionModuleBase = createModule(() => {
  return session({
    secret: 'my-secret-session-key',
    //secret: process.env.MYSECRETSESSIONKEY,
    resave: false,
    saveUninitialized: false,

    cookie: {
      secure: true, 
      httpOnly: true,
      sameSite: 'strict', 
      maxAge: 60000, 
    },
  });
});

@Injectable()
export class NoCacheMiddleware implements NestMiddleware {
  use(req: any, res: any, next: () => void) {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    next();
  }
}

@Module({
  imports: [
    ScheduleModule.forRoot(),
    CookieParserModuleBase.forRoot({}),
    SessionModuleBase.forRoot({}),

    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: Joi.object({
        PORT: Joi.number().required(),
      }),
    }),

    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DB_HOST'),
        port: configService.get<number>('DB_PORT'),
        username: configService.get('DB_USERNAME'),
        password: configService.get('DB_PASSWORD'),
        database: configService.get('DB_NAME'),

        //this worked well
        // ssl: {
        //   rejectUnauthorized: true,
        //use perm file to prevent error
        //   ca: process.env.DB_SSL
        // },
       
        //allow this for prod
        ssl: isProduction
          ? {
              rejectUnauthorized: true,
              ca:Buffer.from(process.env.DB_SSLG || '', 'base64').toString()

            }
          : false,


        autoLoadEntities: true,
        //synchronize: !isProduction,
        synchronize: true,
        //change this whilst going live ...
        //synchronize: false,
      }),
      inject: [ConfigService],
    }),

    ProductModule,

  ],
  controllers: [AppController],
  providers: [
    AppService,
    //AuditMiddleware
  ],
})
// export class AppModule implements NestModule {
//   configure(consumer: MiddlewareConsumer) {
//     consumer.apply(NoCacheMiddleware).forRoutes('*');
//     // this handles the audit trail for the app
//     //  consumer.apply(AuditMiddleware).forRoutes({ path: '*', method: RequestMethod.ALL });
//     //for individual routes
//     //{ path: 'users/*', method: RequestMethod.ALL } // Apply to all user routes
//   }
// }
export class AppModule {}
