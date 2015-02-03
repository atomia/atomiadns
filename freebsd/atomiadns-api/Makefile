# $FreeBSD$

PORTNAME=	atomiadns
PORTVERSION=	1.1.34
CATEGORIES=	dns
MASTER_SITES=	http://www.atomiadns.com/tarballs/
PKGNAMESUFFIX=	-api
DISTNAME=	${PORTVERSION}

MAINTAINER=	jimmy@sigint.se
COMMENT=	Atomia DNS API server

LICENSE=	ISCL

USE_APACHE=	22
USES=		perl5
USE_PERL5=	configure
WRKSRC=		${WRKDIR}/${PORTNAME}-${PORTVERSION}/server

RUN_DEPENDS	+=	p5-Config-General>=0:${PORTSDIR}/devel/p5-Config-General
RUN_DEPENDS	+=	p5-DBD-Pg>=2.11.7:${PORTSDIR}/databases/p5-DBD-Pg
RUN_DEPENDS	+=	p5-SOAP-Lite>=0.710.08:${PORTSDIR}/net/p5-SOAP-Lite
RUN_DEPENDS	+=	p5-Moose>=0.94:${PORTSDIR}/devel/p5-Moose
RUN_DEPENDS	+=	p5-JSON>=0:${PORTSDIR}/converters/p5-JSON
RUN_DEPENDS	+=	p5-Authen-Passphrase>=0.006:${PORTSDIR}/security/p5-Authen-Passphrase
RUN_DEPENDS	+=	p5-Digest-SHA1>=0:${PORTSDIR}/security/p5-Digest-SHA1
RUN_DEPENDS	+=	p5-Net-DNS>=0:${PORTSDIR}/dns/p5-Net-DNS
RUN_DEPENDS	+=	p5-Net-DNS-SEC>=0:${PORTSDIR}/dns/p5-Net-DNS-SEC
RUN_DEPENDS	+=	ap22-mod_perl2>=2:${PORTSDIR}/www/mod_perl2

post-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/etc/apache22/Includes
	${INSTALL_DATA} ${WRKSRC}/conf/apache-example ${STAGEDIR}${PREFIX}/etc/apache22/Includes/atomiadns.conf
	PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.mk>
