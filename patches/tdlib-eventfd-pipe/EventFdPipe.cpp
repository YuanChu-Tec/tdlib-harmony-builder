//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2026
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/EventFdPipe.h"

char disable_linker_warning_about_empty_file_event_fd_pipe_cpp TD_UNUSED;

#ifdef TD_EVENTFD_PIPE

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

#include <cerrno>

#include <fcntl.h>
#include <poll.h>
#include <unistd.h>

namespace td {
namespace detail {

EventFdPipe::EventFdPipe() = default;

EventFdPipe::EventFdPipe(EventFdPipe &&) noexcept = default;

EventFdPipe &EventFdPipe::operator=(EventFdPipe &&) noexcept = default;

EventFdPipe::~EventFdPipe() = default;

void EventFdPipe::init() {
  int pipe_fds[2];
  int err = pipe(pipe_fds);
  auto pipe_errno = errno;
  LOG_IF(FATAL, err != 0) << Status::PosixError(pipe_errno, "pipe failed");

  auto read_fd = NativeFd(pipe_fds[0]);
  auto write_fd = NativeFd(pipe_fds[1]);
  read_fd.set_is_blocking_unsafe(false).ensure();
  write_fd.set_is_blocking_unsafe(false).ensure();

  impl_ = make_unique<Impl>();
  impl_->read_info_.set_native_fd(std::move(read_fd));
  impl_->write_fd_ = std::move(write_fd);
}

bool EventFdPipe::empty() {
  return !impl_;
}

void EventFdPipe::close() {
  impl_.reset();
}

Status EventFdPipe::get_pending_error() {
  return Status::OK();
}

PollableFdInfo &EventFdPipe::get_poll_info() {
  return impl_->read_info_;
}

void EventFdPipe::release() {
  const char value = 1;
  auto slice = Slice(&value, 1);
  auto native_fd = impl_->write_fd_.fd();

  auto result = [&]() -> Result<size_t> {
    auto write_res = detail::skip_eintr([&] { return write(native_fd, slice.begin(), slice.size()); });
    auto write_errno = errno;
    if (write_res >= 0) {
      return narrow_cast<size_t>(write_res);
    }
    return Status::PosixError(write_errno, PSLICE() << "EventFdPipe write failed");
  }();

  if (result.is_error()) {
    LOG(FATAL) << "EventFdPipe write failed: " << result.error();
  }
  if (result.ok() != 1) {
    LOG(FATAL) << "EventFdPipe write returned " << result.ok() << " instead of 1";
  }
}

void EventFdPipe::acquire() {
  impl_->read_info_.sync_with_poll();
  SCOPE_EXIT {
    get_poll_info().clear_flags(PollFlags::Read());
  };
  char buf;
  auto slice = MutableSlice(&buf, 1);
  auto native_fd = impl_->read_info_.native_fd().fd();

  auto result = [&]() -> Result<size_t> {
    auto read_res = detail::skip_eintr([&] { return ::read(native_fd, slice.begin(), slice.size()); });
    auto read_errno = errno;
    if (read_res >= 0) {
      return narrow_cast<size_t>(read_res);
    }
    if (read_errno == EAGAIN || read_errno == EWOULDBLOCK) {
      return 0;
    }
    return Status::PosixError(read_errno, PSLICE() << "EventFdPipe read failed");
  }();

  if (result.is_error()) {
    LOG(FATAL) << "EventFdPipe read failed: " << result.error();
  }
}

void EventFdPipe::wait(int timeout_ms) {
  detail::skip_eintr_timeout(
      [this](int timeout_ms) {
        pollfd pfd;
        pfd.fd = get_poll_info().native_fd().fd();
        pfd.events = POLLIN;
        return poll(&pfd, 1, timeout_ms);
      },
      timeout_ms);
}

}  // namespace detail
}  // namespace td

#endif
