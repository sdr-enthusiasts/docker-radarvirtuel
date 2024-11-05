/*
ANFEEDER.C - COPYRIGHT (C) 2022-2024 BY ADSBNETWORK, LAURENT DUVAL, THIERRY LECONTE, AND CONTRIBUTORS.
THIS SOFTWARE IS NOT LICENSED UNDER AN OPEN SOURCE LICENSE. ALL RIGHTS RESERVED.

- USE IS ONLY PERMITTED TO FACILITATE FEEDING ADSB DATA TO ADSBNETWORK AND/OR RADARVIRTUEL AS PART OF SDR-ENTHUSIASTS' DOCKER-RADARVIRTUEL CONTAINER
- DISTRIBUTION OF THE SOFTWARE, IN ANY FORMAT, INCLUDING BUT NOT LIMITED TO SOURCE, OBJECT, OR BINARY FORMAT, IS PROHIBITED. NOTWITHSTANDING THE FOREGOING, 
  IT SHALL BE PERMITTED TO INCLUDE THE SOURCE CODE OF THIS SOFTWARE IN A CLONE OF THE SDR-ENTHUSIASTS/DOCKER-RADARVIRTUEL GITHUB REPOSITORY IF THE ONLY
  PURPOSE OF THIS CLONE IS TO CONTRIBUTE AND/OR TEST CHANGES TO THE ORIGINAL SDR-ENTHUSIASTS/DOCKER-RADARVIRTUEL REPOSITORY FOR THE BENEFIT OF ADSBNETWORK.
- ANY OTHER USE IS EXPRESSLY PROHIBITED UNLESS WRITTEN PERMISSION IS OBTAINED FROM AN AUTHORIZED REPRESENTATIVE OF ADSBNETWORK.
  CONTACT LAURENT DUVAL, CEO OF ADSB NETWORK - laurent.duval@adsbnetwork.com
- THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>

// Les variables globales sont utilisées ici sans redéfinition
extern int srcsock, dstsock;
extern int verbose;
extern int mode;
extern int fmode;
extern char stid[9];
extern char *key;

uint32_t compute_crc(uint8_t *msg, size_t msg_len) {
    uint32_t crc = 0;
    for (size_t i = 0; i < msg_len; i++) {
        crc ^= msg[i];
    }
    return crc;
}

int process_adsb_message(uint8_t *msg, size_t msg_len) {
    uint32_t crc = compute_crc(msg, msg_len);
    if (crc != 0) {
        if (verbose) {
            fprintf(stderr, "Trame ADS-B ignorée: CRC invalide\n");
        }
        return -1;
    }
    send(dstsock, msg, msg_len, 0);
    sleep(2);  // Ajout d'une pause de 2 secondes après l'envoi du message
    return 0;
}

/* Copyright (c) Thierry Leconte 2016 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <arpa/inet.h>

int srcsock,dstsock;
int verbose;
int mode=0;
int fmode=0;
char stid[9];
char *key=NULL;

int netconnect(char *inaddr, char *defport, int type)
{
    struct addrinfo hints,*servinfo,*p;
    int rv;
    char *port;
    int netsock;
    char *addr,*caddr;

    if(inaddr==NULL) return -1;
    caddr=strdup(inaddr);

    memset(&hints, 0, sizeof hints);
    hints.ai_socktype = type;
    hints.ai_flags = AI_ADDRCONFIG;

    if (caddr[0] == '[') {
           hints.ai_family = AF_INET6;
           addr = caddr + 1;
           port = strstr(addr, "]");
           if (port == NULL) {
        	fprintf(stderr, "bad address : %s\n", addr);
		return -1;
           }
           *port = 0;
           port++;
           if (*port != ':')
		 port = defport;
           else
                 port++;
    } else {
           hints.ai_family = AF_UNSPEC;
           addr = caddr;
           port = strstr(addr, ":");
           if (port == NULL)
                 port = defport;
           else {
                *port = 0;
                port++;
           }
    }


    if ((rv = getaddrinfo(addr, port, &hints, &servinfo)) != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rv));
	free(caddr);
        return -1;
    }

    free(caddr);

    // loop through all the results and connect to the first we can
    netsock=-1;
    for(p = servinfo; p != NULL; p = p->ai_next) {
        if ((netsock = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            continue;
        }

        if (connect(netsock, p->ai_addr, p->ai_addrlen) == 0) 
            break;

        close(netsock); netsock=-1;
    }
    freeaddrinfo(servinfo);

    return netsock;
}

static const uint32_t modes_checksum_table[112] = {
0x3935ea, 0x1c9af5, 0xf1b77e, 0x78dbbf, 0xc397db, 0x9e31e9, 0xb0e2f0, 0x587178,
0x2c38bc, 0x161c5e, 0x0b0e2f, 0xfa7d13, 0x82c48d, 0xbe9842, 0x5f4c21, 0xd05c14,
0x682e0a, 0x341705, 0xe5f186, 0x72f8c3, 0xc68665, 0x9cb936, 0x4e5c9b, 0xd8d449,
0x939020, 0x49c810, 0x24e408, 0x127204, 0x093902, 0x049c81, 0xfdb444, 0x7eda22,
0x3f6d11, 0xe04c8c, 0x702646, 0x381323, 0xe3f395, 0x8e03ce, 0x4701e7, 0xdc7af7,
0x91c77f, 0xb719bb, 0xa476d9, 0xadc168, 0x56e0b4, 0x2b705a, 0x15b82d, 0xf52612,
0x7a9309, 0xc2b380, 0x6159c0, 0x30ace0, 0x185670, 0x0c2b38, 0x06159c, 0x030ace,
0x018567, 0xff38b7, 0x80665f, 0xbfc92b, 0xa01e91, 0xaff54c, 0x57faa6, 0x2bfd53,
0xea04ad, 0x8af852, 0x457c29, 0xdd4410, 0x6ea208, 0x375104, 0x1ba882, 0x0dd441,
0xf91024, 0x7c8812, 0x3e4409, 0xe0d800, 0x706c00, 0x383600, 0x1c1b00, 0x0e0d80,
0x0706c0, 0x038360, 0x01c1b0, 0x00e0d8, 0x00706c, 0x003836, 0x001c1b, 0xfff409,
0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000,
0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000,
0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000, 0x000000
};

static uint32_t modesChecksum(unsigned char *msg, int bits) {
    uint32_t   crc = 0;
    uint32_t   rem = 0;
    int        offset = (bits == 112) ? 0 : (112-56);
    uint8_t    theByte = *msg;
    const uint32_t *pCRCTable = &modes_checksum_table[offset];
    int j;

    bits -= 24;
    for(j = 0; j < bits; j++) {
       if ((j & 7) == 0)
             theByte = *msg++;
  
       if (theByte & 0x80) {crc ^= *pCRCTable;}
       pCRCTable++;
       theByte = theByte << 1;
    }

    rem = (msg[0] << 16) | (msg[1] << 8) | msg[2]; // message checksum
    return ((crc ^ rem) & 0x00FFFFFF); // 24 bit checksum syndrome.
}

static int filter(unsigned char *mm,int len)
{
unsigned int type;
uint32_t crc;

type=(unsigned int)(mm[0]>>3);

if(type == 17 || type == 18) return 1;
if(fmode && type == 11 && modesChecksum(mm,len*8)==0) return 1;
if((type == 5 || type == 21) &&
   (((mm[2] << 8) | mm[3]) & 0x1FFF)
  )  return 1;

return 0;
}

static int build_pck(unsigned char *sbuff,char *st,uint64_t tm,uint64_t tst)
{
	unsigned char *ps,*ad;
	uint64_t tt;
	int j;

	/* build packet header */
	ps=sbuff;
	if(mode) *ps='B'; else  *ps='A';
        ps++;
	memcpy(ps,stid,6);ps+=6;

	tt=tm*1000000L+(tst*83L)%1000000L;
	for (j = 7; j >= 0; j--) {
        	*ps++ = (tt>>8*j)&0xff;
 	}
	for (j = 3; j >= 0; j--) {
        	*ps++ = 0;
    	}
	/* fill packet */
	ad=ps;
	while(*st) {
		unsigned char v;
		sscanf(st,"%02hhX",&v);
		*ps++=v;
		st+=2;
	}
	/* filter */
	if(filter(ad,ps-ad))
		return (ps-sbuff);
	else
		return 0;
}

const unsigned int num_rounds=16;
static inline void en(uint32_t v[2], const uint32_t key[4]) {
    unsigned int i;
    uint32_t v0=v[0], v1=v[1], sum=0, delta=0x9E3779B9;
    for (i=0; i < num_rounds; i++) {
        v0 += (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
        sum += delta;
        v1 += (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum>>11) & 3]);
    }
    v[0]=v0; v[1]=v1;
}

static uint32_t skey[4];
static int build_crypt_pck(unsigned char *sbuff,char *st,uint64_t tm,uint64_t tst)
{
	unsigned char *ps,*ad,*cy;
	int j;
	uint64_t tns;

	/* build packet header */
	ps=sbuff;
	*ps='C';
        ps++;
	memcpy(ps,stid,8);ps+=8;

	cy=ps;
	for (j = 5; j >= 0; j--) {
        	*ps++ = (tm>>8*j)&0xff;
 	}
	tns=tst*83L;
	for (j = 3; j >= 0; j--) {
        	*ps++ = (tns>>8*j)&0xff;
    	}
	/* fill packet */
	ad=ps;
	while(*st) {
		unsigned char v;
		sscanf(st,"%02hhX",&v);
		*ps++=v;
		st+=2;
	}
	/* filter */
	if(filter(ad,ps-ad)) {
		unsigned char *cp;
		/* crypt */
		memset(ps,0,4);
		for(cp=cy;cp<ps;cp+=8)
			en((uint32_t*)cp,skey);
		
		return (cp-sbuff);
	} else
		return 0;
}

#define BSZ 256
static void transmit(void) 
{
    char mess[BSZ+1];
    char *st;
    int len;

    st=mess;
    len=0;
    do {
	char *cr,md;
        struct timespec tp;
        uint64_t tm,tst;
	unsigned char sbuff[100];
	int sv,ct,j;

	if(len<BSZ) {
	  ct=read(srcsock,&(mess[len]),BSZ-len);
	  if(ct<=0) {
       		if(verbose) fprintf(stderr,"lose local connection \n");
		close(srcsock);srcsock=-1;
		break;
	  }
	  len+=ct;mess[len]=0;
	}

	/* find packet start */
	md=*mess;
	if(md!='@' && md!='*') {
		st=strchr(mess,'@');
		if(st==NULL) st=strchr(mess,'*');
		if(st==NULL) { len=0; continue; }
		len-=st-mess;
		memmove(mess,st,len);
		md=*mess;
	}
        clock_gettime(CLOCK_REALTIME, &tp);
	tm=(uint64_t)tp.tv_sec*1000L+(uint64_t)tp.tv_nsec/1000000L;

	/* find packet end */
	cr=strchr(mess,';');
	if(cr==NULL) { len=0; continue; }
	*cr='\0';

	st=mess+1;
	if(md=='@') {
		int v;
		if(strlen(st)<26) goto next;
		tst=0;
		for (j = 5; j >= 0; j--) {
			sscanf(st,"%02X",&v);
			tst<<=8; tst+=v;
			st+=2;
		}
	} else {
		if(strlen(st)<14) goto next;
		tst=0;
	}

	//if(verbose) printf("%s\n",st);

	if(key)
		sv=build_crypt_pck(sbuff,st,tm,tst);
	else
		sv=build_pck(sbuff,st,tm,tst);

	if(sv) {
		/* send */
		ct=write(dstsock,sbuff,sv);
		if(ct!=sv) {
       			if(verbose) fprintf(stderr,"write error %s\n",strerror(errno));
			if(errno==EBADF || errno==EINVAL) {
				close(dstsock);dstsock=-1;
				return;
			}
		}
	}

next:
	st=cr+1;
	len-=st-mess;
	memmove(mess,st,len);

     } while(1);
}

int main(int argc, char **argv)
{
        int c;
	char *srcaddr,*dstaddr;

	memset(stid,0,9);
	dstaddr=NULL;
	srcaddr="127.0.0.1";

        while ((c = getopt(argc, argv, "vs:d:i:cf")) != EOF) {
                switch ((char)c) {
                case 'v':
                        verbose=1;
                        break;
                case 's':
                        srcaddr=optarg;
                        break;
                case 'd':
                        dstaddr=optarg;
                        break;
                case 'i':
                        strncpy(stid,strtok(optarg,":"),8);
			key=strtok(NULL,":");
                        break;
                case 'c':
                        mode=1;
                        break;
                case 'f':
                        fmode=1;
                        break;
                default:
			fprintf(stderr,"ANfeeder v1.1 (c) Thierry Leconte\n");
			fprintf(stderr,"ANfeeder -istid:key -d addr:port  [-s addr[:port]] [-v] [-f]\n");
                        return(1);
                }
        }

	if(*stid==0) {
		fprintf(stderr,"Need station id (-i stid) \n");
		return 1;
	}
	if(dstaddr==NULL) {
		fprintf(stderr,"Need destination addr (-d addr:port)\n");
		return 1;
	}
	srcsock=dstsock=-1;

	if(key)
	 if(strlen(key)==32) {
		int j;
 		for(j=0;j<4;j++)
			sscanf(&(key[8*j]),"%08X",&(skey[j]));
	 } else {
		fprintf(stderr,"Wrong ket len\n");
		return 1;
	 }

	/* main infinite loop */
	do {

	  while(dstsock<0) {
		dstsock=netconnect(dstaddr, "0", SOCK_DGRAM);
		if(dstsock<0) sleep(20);
	  }

	  while(srcsock<0) {
		srcsock=netconnect(srcaddr, "30002", SOCK_STREAM);
		if(srcsock<0) {
			if(verbose) fprintf(stderr,"could not connect to %s\n",srcaddr);
			sleep(5);
		}
	 }

	  transmit();

	} while(1);
}
