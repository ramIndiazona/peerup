import {
    Controller,
    Get,
    HttpCode,
    Param,
    Post,
    UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { FriendRequestsService } from './friend-requests.service';

@ApiTags('friend-requests')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('friend-requests')
export class FriendRequestsController {
    constructor(
        private readonly friendRequests: FriendRequestsService,
    ) { }

    @Post(':userId')
    @HttpCode(201)
    @ApiOperation({ summary: 'Send a friend request' })
    send(
        @CurrentUser('id') userId: string,
        @Param('userId') receiverId: string,
    ) {
        return this.friendRequests.sendRequest(userId, receiverId);
    }

    @Get('received')
    @ApiOperation({ summary: 'List received pending friend requests' })
    received(@CurrentUser('id') userId: string) {
        return this.friendRequests.receivedRequests(userId);
    }

    @Get('sent')
    @ApiOperation({ summary: 'List sent pending friend requests' })
    sent(@CurrentUser('id') userId: string) {
        return this.friendRequests.sentRequests(userId);
    }

    @Post(':requestId/accept')
    @HttpCode(200)
    @ApiOperation({ summary: 'Accept a friend request' })
    accept(
        @CurrentUser('id') userId: string,
        @Param('requestId') requestId: string,
    ) {
        return this.friendRequests.acceptRequest(userId, requestId);
    }
    @Get('friends')
    @ApiOperation({ summary: 'List all accepted friends' })
    friends(@CurrentUser('id') userId: string) {
        return this.friendRequests.listFriends(userId);
    }

    @Post(':requestId/decline')
    @HttpCode(200)
    @ApiOperation({ summary: 'Decline a friend request' })
    decline(
        @CurrentUser('id') userId: string,
        @Param('requestId') requestId: string,
    ) {
        return this.friendRequests.declineRequest(userId, requestId);
    }

    @Post(':requestId/cancel')
    @HttpCode(200)
    @ApiOperation({ summary: 'Cancel a sent friend request' })
    cancel(
        @CurrentUser('id') userId: string,
        @Param('requestId') requestId: string,
    ) {
        return this.friendRequests.cancelRequest(userId, requestId);
    }
}