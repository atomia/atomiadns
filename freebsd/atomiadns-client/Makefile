# $FreeBSD$

PORTNAME=	atomiadns
PORTVERSION=	1.1.36
CATEGORIES=	dns
MASTER_SITES=	http://www.atomiadns.com/tarballs/
PKGNAMESUFFIX=	-client
DISTNAME=	${PORTVERSION}

MAINTAINER=	jimmy@sigint.se
COMMENT=	Atomia DNS command line client

LICENSE=	ISCL

USES=		perl5
USE_PERL5=	configure
WRKSRC=		${WRKDIR}/${PORTNAME}-${PORTVERSION}/server/client

RUN_DEPENDS	+=	p5-Config-General>=0:${PORTSDIR}/devel/p5-Config-General
RUN_DEPENDS	+=	p5-SOAP-Lite>=0.710.08:${PORTSDIR}/net/p5-SOAP-Lite

post-install:
	PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.mk>
