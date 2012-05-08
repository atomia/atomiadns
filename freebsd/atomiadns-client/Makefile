# New ports collection makefile for:	Atomia DNS command line client
# Date created:				Mon May  7 10:45:05 CEST 2012
# Whom:					Jimmy Bergman <jimmy@sigint.se>
#
# $FreeBSD$
#

PORTNAME=	atomiadns
PORTVERSION=	1.1.7
CATEGORIES=	dns
MASTER_SITES=	https://nodeload.github.com/atomia/atomiadns/tarball/
PKGNAMESUFFIX=	-client
DISTNAME=	${PORTVERSION}
EXTRACT_SUFX=

MAINTAINER=	jimmy@sigint.se
COMMENT=	The Atomia DNS command line client

LICENSE=	ISCL

PERL_CONFIGURE=	yes
WRKSRC=		${WRKDIR}/atomia-atomiadns-05a2c15/server/client

MAN1=		atomiadnsclient.1 dnssec_zsk_rollover.1

RUN_DEPENDS	+=	p5-Config-General>=0:${PORTSDIR}/devel/p5-Config-General
RUN_DEPENDS	+=	p5-SOAP-Lite>=0.710.08:${PORTSDIR}/net/p5-SOAP-Lite

post-install:
	PKG_PREFIX=${PREFIX} ${SH} ${PKGINSTALL} ${PKGNAME} POST-INSTALL

.include <bsd.port.mk>
