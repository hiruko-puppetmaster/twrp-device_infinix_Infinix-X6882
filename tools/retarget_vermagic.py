#!/usr/bin/env python3
"""Rewrite the release part of vermagic= inside .modinfo, preserving section size."""
import os, sys, struct

def modinfo_span(d):
    shoff=struct.unpack_from('<Q',d,0x28)[0]
    shentsize,shnum,shstrndx=struct.unpack_from('<HHH',d,0x3A)
    def sh(i):
        b=shoff+i*shentsize
        return struct.unpack_from('<IIQQQQIIQQ',d,b)
    st=sh(shstrndx); sd=d[st[4]:st[4]+st[5]]
    for i in range(shnum):
        name,typ,flags,addr,off,size=sh(i)[:6]
        nm=sd[name:sd.find(b'\0',name)].decode()
        if nm=='.modinfo': return off,size
    return None

def patch(path, old, new):
    assert len(new) <= len(old)
    d=bytearray(open(path,'rb').read())
    span=modinfo_span(d)
    if not span: return 'no-modinfo'
    off,size=span
    sec=bytes(d[off:off+size])
    needle=b'vermagic='+old.encode()
    i=sec.find(needle)
    if i<0: return 'no-match'
    j=i+len(needle)
    if sec[j:j+1] != b' ': return 'bad-suffix'
    if sec.find(needle,i+1)>=0: return 'multiple'
    delta=len(old)-len(new)
    newsec=sec[:i]+b'vermagic='+new.encode()+sec[j:]
    assert len(newsec)==size-delta
    newsec+=b'\0'*delta
    d[off:off+size]=newsec
    open(path,'wb').write(d)
    return 'patched'

if __name__=='__main__':
    old,new=sys.argv[1],sys.argv[2]
    counts={}
    for r in sys.argv[3:]:
        for dp,_,fns in os.walk(r):
            for fn in sorted(fns):
                if fn.endswith('.ko'):
                    res=patch(os.path.join(dp,fn),old,new)
                    counts[res]=counts.get(res,0)+1
                    if res!='patched': print(f"  {res}: {os.path.join(dp,fn)}")
    print("result:",counts)
