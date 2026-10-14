import {
  Body,
  Controller,
  Get,
  Param,
  ParseArrayPipe,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';

import { TongueTwistersService } from './tongue-twisters.service';
import { CreateTongueTwisterDto } from './dto/create-tongue-twister.dto';

@Controller('tongue-twisters')
export class TongueTwistersController {
  constructor(
    private readonly tongueTwistersService: TongueTwistersService,
  ) { }

  @Get()
  findAll() {
    return this.tongueTwistersService.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.tongueTwistersService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateTongueTwisterDto) {
    return this.tongueTwistersService.create(dto);
  }

  @Post('bulk')
  createMany(
    @Body(new ParseArrayPipe({ items: CreateTongueTwisterDto }))
    items: CreateTongueTwisterDto[],
  ) {
    return this.tongueTwistersService.createMany(items);
  }
}