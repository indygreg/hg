/*
 * Utility to send fds via Unix domain socket
 *
 * Copyright 2011, 2018 Yuya Nishihara <yuya@tcha.org>
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2 or any later version.
 */

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>

#define MAX_FD_LEN 10

/*
 * Sends the given fds with 1-byte dummy payload.
 *
 * Returns the number of bytes sent on success, -1 on error and errno is set
 * appropriately.
 */
ssize_t sendfds(int sockfd, const int *fds, size_t fdlen)
{
	char dummy[1] = {0};
	struct iovec iov = {dummy, sizeof(dummy)};
	char fdbuf[CMSG_SPACE(sizeof(fds[0]) * MAX_FD_LEN)];
	struct msghdr msgh;
	struct cmsghdr *cmsg;

	/* just use a fixed-size buffer since we'll never send tons of fds */
	if (fdlen > MAX_FD_LEN) {
		errno = EINVAL;
		return -1;
	}

	memset(&msgh, 0, sizeof(msgh));
	msgh.msg_iov = &iov;
	msgh.msg_iovlen = 1;
	msgh.msg_control = fdbuf;
	msgh.msg_controllen = CMSG_SPACE(sizeof(fds[0]) * fdlen);

	cmsg = CMSG_FIRSTHDR(&msgh);
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	cmsg->cmsg_len = CMSG_LEN(sizeof(fds[0]) * fdlen);
	memcpy(CMSG_DATA(cmsg), fds, sizeof(fds[0]) * fdlen);
	msgh.msg_controllen = cmsg->cmsg_len;
	return sendmsg(sockfd, &msgh, 0);
}
