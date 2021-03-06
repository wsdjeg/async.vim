let s:save_cpo = &cpo
set cpo&vim

let s:nvim_jobcontrol = has('nvim')
let s:vim_jobcontrol = !has('nvim') && has('job') && has('patch-7-4-1590')

function! WarnNotSupported()
    echo 'not supported for sync jobs'
endfunction

function! s:warp_vim_startjob(argv, opts)
    let obj = {}
    let obj._argv = a:argv
    let obj._opts = a:opts

    function! obj._out_cb(job_id, data)
        if has_key(self._opts, 'on_stdout')
            call self._opts.on_stdout(a:job_id, [a:data], 'stdout')
        endif
    endfunction

    function! obj._err_cb(job_id, data)
        if has_key(self._opts, 'on_stderr')
            call self._opts.on_stderr(a:job_id, [a:data], 'stderr')
        endif
    endfunction

    function! obj._exit_cb(job_id, data)
        if has_key(self._opts, 'on_exit')
            call self._opts.on_exit(a:job_id, [a:data], 'exit')
        endif
    endfunction

    let obj = {
        \ 'argv': a:argv,
        \ 'opts': {
            \ 'mode': 'nl',
            \ 'out_cb': obj._out_cb,
            \ 'err_cb': obj._err_cb,
            \ 'exit_cb': obj._exit_cb,
            \ }
        \ }

    return obj
endfunction

let s:job_id_counter = 0

function async#job#start(argv, opts) abort
    if s:nvim_jobcontrol
        return jobstart(a:argv, a:opts)
    elseif s:vim_jobcontrol
        let l:wrapped = s:warp_vim_startjob(a:argv, a:opts)
        return job_start(l:wrapped.argv, l:wrapped.opts)
    else
        let s:job_id_counter = s:job_id_counter + 1
        let l:stdout = system(join(a:argv, ' '))
        let l:job_id = 'system_' . s:job_id_counter
        if has_key(a:opts, 'on_stdout')
            call a:opts.on_stdout(l:job_id, split(l:stdout, '\r\?\n', 1), 'stdout')
        endif
        if has_key(a:opts, 'on_exit')
            call a:opts.on_exit(l:job_id, [v:shell_error], 'exit')
        endif
    endif
endfunction

function async#job#stop(job_id) abort
    if s:nvim_jobcontrol
        call jobstop(a:job_id)
    elseif s:vim_jobcontrol
        call job_stop(a:job_id)
    elseif type(job_id) == type('') && job_id =~ 'system_'
        call WarnNotSupported()
    endif
endfunction

function async#job#send(job_id, data) abort
    if s:nvim_jobcontrol
        call jobsend(a:job_id, a:data)
    elseif s:vim_jobcontrol
        call job_send(job_id)
    else
        call WarnNotSupported()
    endif
endfunction

