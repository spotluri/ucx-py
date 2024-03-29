# Copyright (c) 2018, NVIDIA CORPORATION. All rights reserved.
# See file LICENSE for terms.

cdef extern from "myucp.h":
    ctypedef void (*callback_func)(char *name, void *user_data)
    void set_req_cb(callback_func user_py_func, void *user_data)

cdef extern from "myucp.h":
    cdef struct ucx_context:
        int completed
    cdef struct data_buf:
        void* buf

cdef extern from "myucp.h":
    int init_ucp(char *)
    int fin_ucp()
    int setup_ep_ucp()
    int destroy_ep_ucp()
    data_buf* allocate_host_buffer(int)
    data_buf* allocate_cuda_buffer(int)
    int set_host_buffer(data_buf*, int, int)
    int set_cuda_buffer(data_buf*, int, int)
    int check_host_buffer(data_buf*, int, int)
    int check_cuda_buffer(data_buf*, int, int)
    int free_host_buffer(data_buf*)
    int free_cuda_buffer(data_buf*)
    ucx_context* send_nb_ucp(data_buf*, int);
    ucx_context* recv_nb_ucp(data_buf*, int);
    int wait_request_ucp(ucx_context*)
    int query_request_ucp(ucx_context*)
    int barrier_sock()

cdef class buffer_region:
    cdef data_buf* buf
    cdef int is_cuda

    def __cinit__(self):
        return

    def alloc_host(self, len):
        self.buf = allocate_host_buffer(len)
        self.is_cuda = 0

    def alloc_cuda(self, len):
        self.buf = allocate_cuda_buffer(len)
        self.is_cuda = 1

    def free_host(self):
        free_host_buffer(self.buf)

    def free_cuda(self):
        free_cuda_buffer(self.buf)

cdef class ucp_msg:
    cdef ucx_context* ctx_ptr
    cdef data_buf* buf
    cdef int is_cuda

    def __cinit__(self, buffer_region buf_reg):
        if buf_reg is None:
            return
        else:
            self.buf = buf_reg.buf
            self.is_cuda = buf_reg.is_cuda
        return

    def alloc_host(self, len):
        self.buf = allocate_host_buffer(len)
        self.is_cuda = 0

    def alloc_cuda(self, len):
        self.buf = allocate_cuda_buffer(len)
        self.is_cuda = 1

    def set_mem(self, c, len):
        if 0 == self.is_cuda:
             set_host_buffer(self.buf, c, len)
        else:
             set_cuda_buffer(self.buf, c, len)

    def check_mem(self, c, len):
        if 0 == self.is_cuda:
             return check_host_buffer(self.buf, c, len)
        else:
             return check_cuda_buffer(self.buf, c, len)

    def free_host(self):
        free_host_buffer(self.buf)

    def free_cuda(self):
        free_cuda_buffer(self.buf)

    def send(self, len):
        self.ctx_ptr = send_nb_ucp(self.buf, len)

    def recv(self, len):
        self.ctx_ptr = recv_nb_ucp(self.buf, len)

    def wait(self):
        wait_request_ucp(self.ctx_ptr)

    def query(self):
        return query_request_ucp(self.ctx_ptr)

cdef void callback(char *name, void *f):
    (<object>f)(name.decode('utf-8')) #assuming pyfunc callback accepts char *

def set_callback(f):
    set_req_cb(callback, <void*>f)

def init(str):
    return init_ucp(str)

def fin():
    return fin_ucp()

def setup_ep():
    return setup_ep_ucp()

def destroy_ep():
    return destroy_ep_ucp()

def barrier():
    return barrier_sock()
